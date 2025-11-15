use bluer::{
    adv::Advertisement,
    gatt::local::{
        Application, Characteristic, CharacteristicRead, CharacteristicWrite, CharacteristicWriteMethod,
        Service,
    },
    Uuid,
};
use futures::FutureExt;
use std::{
    collections::{BTreeSet, VecDeque},
    sync::Arc,
    time::Duration,
};
use tokio::{sync::Mutex, time::sleep};

const SRV_UUID: Uuid = Uuid::from_u128(0x8b322909_2d3b_447b_a4d5_dfe0c009ec5a);
const WR_CHAR_UUID: Uuid = Uuid::from_u128(0x8b32290a_2d3b_447b_a4d5_dfe0c009ec5a);
const INFO_UUID:    Uuid = Uuid::from_u128(0x8b32290c_2d3b_447b_a4d5_dfe0c009ec5a);
const HISTORY_MAX: usize = 8;

#[derive(Clone, Debug)]
struct GridFrame {
    rows: usize,
    cols: usize,
    data: Vec<Vec<f32>>,
}

#[derive(Default)]
struct AppState {
    last_raw: Vec<u8>,
    last_grid: Option<GridFrame>,
    history: VecDeque<GridFrame>,
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    env_logger::init();

    let session = bluer::Session::new().await.expect("create bluer session");
    let adapter = session.default_adapter().await.expect("get default adapter");
    adapter.set_powered(true).await.expect("power on adapter");
    let mut svc = BTreeSet::new();
    svc.insert(SRV_UUID);
    let adv = Advertisement {
        service_uuids: svc,
        discoverable: Some(true),
        local_name: Some("WHV Haptic Receiver".to_string()),
        ..Default::default()
    };
    let _adv_handle = adapter.advertise(adv).await.expect("start advertising");

    let state = Arc::new(Mutex::new(AppState::default()));
    let state_for_write = Arc::clone(&state);
    let state_for_read  = Arc::clone(&state);
    
    let app = Application {
        services: vec![Service {
            uuid: SRV_UUID,
            primary: true,
            characteristics: vec![
                Characteristic {
                    uuid: WR_CHAR_UUID,
                    write: Some(CharacteristicWrite {
                        write: true,
                        write_without_response: true,
                        method: CharacteristicWriteMethod::Fun(Box::new(move |data, _req| {
                            let state_for_write = Arc::clone(&state_for_write);
                            async move {
                                print!("RX {} bytes: [", data.len());
                                for (i, b) in data.iter().enumerate() {
                                    if i > 0 { print!(" "); }
                                    print!("{:02X}", b);
                                }
                                println!("]");
                                {
                                    let mut st = state_for_write.lock().await;
                                    st.last_raw = data.clone();
                                }
                                if !data.is_empty() && (data[0] == b'{' || data[0] == b'[') {
                                    if let Some(grid) = parse_json_grid(&data) {
                                        let mut st = state_for_write.lock().await;
                                        st.last_grid = Some(grid.clone());
                                        st.history.push_back(grid.clone());
                                        while st.history.len() > HISTORY_MAX {
                                            st.history.pop_front();
                                        }

                                        println!(
                                            "Parsed JSON grid: {} rows x {} cols (history: {})",
                                            grid.rows, grid.cols, st.history.len()
                                        );

                                        if grid.rows > 0 && grid.cols > 0 {
                                            let r0 = &grid.data[0];
                                            let preview = r0.iter().take(4)
                                                .map(|v| format!("{:.3}", v))
                                                .collect::<Vec<_>>()
                                                .join(", ");
                                            println!("Row0 preview: [{}]{}", preview,
                                                     if grid.cols > 4 { ", …" } else { "" });
                                        }

                                        // send grid to 6 node states over UART
                                        let states = grid_to_node_states_4(&grid);
                                        println!("Node stats to send: {:?}", states);

                                        use serialport::SerialPort;
                                        use std::io::Write;

                                        match serialport::new(
                                            "/dev/ttyACM0",
                                            115200,
                                        )
                                        .timeout(Duration::from_millis(
                                            50,
                                        ))
                                        .open()
                                        {
                                            Ok(mut port) => {
                                                if let Err(e) =
                                                    port.write_all(&states)
                                                {
                                                    eprintln!("Failed to write node states to UART: {e:?}");
                                                }
                                            }
                                            Err(e) => {
                                                eprintln!("Could not open /dev/ttyACM0: {e:?}");
                                            }
                                        }
                                    } else {
                                        println!("JSON detected but failed to parse as a 2D float array.");
                                    }
                                }
                                if data.len() == 4 {
                                    let mut arr = [0u8; 4];
                                    arr.copy_from_slice(&data);
                                    let val = f32::from_le_bytes(arr);
                                    println!("  as f32 (LE): {}", val);
                                }

                                Ok(())
                            }
                            .boxed()
                        })),
                        ..Default::default()
                    }),
                    ..Default::default()
                },
                Characteristic {
                    uuid: INFO_UUID,
                    read: Some(CharacteristicRead {
                        read: true,
                        fun: Box::new(move |_req| {
                            let state_for_read = Arc::clone(&state_for_read);
                            async move {
                                let st = state_for_read.lock().await;
                                let raw_len = st.last_raw.len();
                                let (rows, cols) = st
                                    .last_grid
                                    .as_ref()
                                    .map(|g| (g.rows, g.cols))
                                    .unwrap_or((0, 0));

                                let s = format!(
                                    "WHV Pi5 Receiver v0.1 | last_raw={} bytes | last_grid={}x{} | history={}",
                                    raw_len, rows, cols, st.history.len()
                                );
                                Ok(s.into_bytes())
                            }
                            .boxed()
                        }),
                        ..Default::default()
                    }),
                    ..Default::default()
                },
            ],
            ..Default::default()
        }],
        ..Default::default()
    };

    let _app_handle = adapter
        .serve_gatt_application(app)
        .await
        .expect("serve gatt application");

    println!("BLE receiver is up. Write JSON 2D arrays to {} and I'll store them.", WR_CHAR_UUID);
    loop { sleep(Duration::from_secs(60)).await; }
}

// Helper function to map GridFrame in 4 states
fn grid_to_node_states_4(grid: &GridFrame) -> [u8; 6] {
    // Default all nodes to state 1 (deflated)
    let mut states = [1u8; 6]; // 6 element array for each node

    if grid.rows == 0 || grid.cols == 0 {
        return states;
    }

    // Ensures only 2x3 grid is sent
    let rows = grid.rows.min(2);
    let cols = grid.cols.min(3);

    for r in 0..rows {
        for c in 0..cols {
            let idx = r * 3 + c; // 0..5

            let mut v = grid.data[r][c];
            if v.is_nan() {
                v = 0.0;
            }
            if v < 0.0 {
                v = 0.0;
            }
            if v > 1.0 {
                v = 1.0;
            }

            // Thresholds from grid data
            let state = if v < 0.25 {
                4u8 // least pressure
            } else if v < 0.5 {
                3u8
            } else if v < 0.75 {
                2u8
            } else {
                1u8
            };
            states[idx] = state;
        }
    }
    states
}

fn parse_json_grid(bytes: &[u8]) -> Option<GridFrame> {
    if let Ok(v) = serde_json::from_slice::<Vec<Vec<f32>>>(bytes) {
        return to_grid(v);
    }
    #[derive(serde::Deserialize)]
    struct Obj { grid: Vec<Vec<f32>> }
    if let Ok(obj) = serde_json::from_slice::<Obj>(bytes) {
        return to_grid(obj.grid);
    }
    None
}

fn to_grid(v: Vec<Vec<f32>>) -> Option<GridFrame> {
    let rows = v.len();
    if rows == 0 { return Some(GridFrame { rows: 0, cols: 0, data: v }); }
    let cols = v[0].len();
    if cols == 0 || !v.iter().all(|r| r.len() == cols) {
        return None;
    }
    Some(GridFrame { rows, cols, data: v })
}
