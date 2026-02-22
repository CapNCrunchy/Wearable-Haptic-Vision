use bluer::{
    adv::Advertisement,
    gatt::local::{
        Application, Characteristic, CharacteristicRead, CharacteristicWrite, CharacteristicWriteMethod,
        Service,
    },
    Uuid,
};
use futures::FutureExt;
use log::{error, info, warn};
use std::{
    collections::{BTreeSet, VecDeque},
    io::Write as _,
    sync::{Arc, Mutex as StdMutex},
    time::Duration,
};
use tokio::{sync::{mpsc, Mutex}, time::sleep};

const SRV_UUID: Uuid = Uuid::from_u128(0x8b322909_2d3b_447b_a4d5_dfe0c009ec5a);
const WR_CHAR_UUID: Uuid = Uuid::from_u128(0x8b32290a_2d3b_447b_a4d5_dfe0c009ec5a);
const INFO_UUID: Uuid = Uuid::from_u128(0x8b32290c_2d3b_447b_a4d5_dfe0c009ec5a);

const SERIAL_PATH: &str = "/dev/serial/by-id/usb-Adafruit_Feather_RP2040_DF648C86534125530-if00";
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

    let serial_port = open_serial_once(SERIAL_PATH, 115_200);
    let serial_port = Arc::new(StdMutex::new(serial_port));

    let state = Arc::new(Mutex::new(AppState::default()));

    let (tx, rx) = mpsc::unbounded_channel::<Vec<u8>>();
    spawn_worker(rx, Arc::clone(&state), Arc::clone(&serial_port));

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

    let tx_for_write = tx.clone();
    let state_for_read = Arc::clone(&state);

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
                            let tx_for_write = tx_for_write.clone();
                            async move {
                                let _ = tx_for_write.send(data.clone());
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
                                    "WHV Pi5 Receiver | last_raw={} bytes | last_grid={}x{} | history={}",
                                    raw_len,
                                    rows,
                                    cols,
                                    st.history.len()
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
        .expect("serve gatt");

    info!("BLE receiver is up. Service={SRV_UUID} WriteChar={WR_CHAR_UUID} Serial={SERIAL_PATH}");

    loop {
        sleep(Duration::from_secs(60)).await;
    }
}

fn open_serial_once(path: &str, baud: u32) -> Box<dyn serialport::SerialPort> {
    serialport::new(path, baud)
        .timeout(Duration::from_millis(200))
        .open()
        .unwrap_or_else(|e| panic!("Could not open serial port {path}: {e:?}"))
}

fn spawn_worker(
    mut rx: mpsc::UnboundedReceiver<Vec<u8>>,
    state: Arc<Mutex<AppState>>,
    serial_port: Arc<StdMutex<Box<dyn serialport::SerialPort>>>,
) {
    tokio::spawn(async move {
        while let Some(data) = rx.recv().await {
            {
                let mut st = state.lock().await;
                st.last_raw = data.clone();
            }

            info!("RX {} bytes", data.len());

            if !data.is_empty() && (data[0] == b'{' || data[0] == b'[') {
                if let Some(grid) = parse_json_grid(&data) {
                    let gf = GridFrame {
                        rows: grid.len(),
                        cols: grid.get(0).map(|r| r.len()).unwrap_or(0),
                        data: grid.clone(),
                    };

                    {
                        let mut st = state.lock().await;
                        st.last_grid = Some(gf.clone());
                        st.history.push_back(gf);
                        while st.history.len() > HISTORY_MAX {
                            st.history.pop_front();
                        }
                    }

                    let states = grid_to_node_states_4(&grid);
                    if let Err(e) = write_serial_bytes(&serial_port, &states) {
                        error!("UART write failed: {e:?}");
                    }
                    continue;
                } else {
                    warn!("JSON detected but failed to parse as 2D floats");
                    continue;
                }
            }

            if data.len() >= 6 {
                let to_send = &data[..6];
                if let Err(e) = write_serial_bytes(&serial_port, to_send) {
                    error!("UART write failed: {e:?}");
                }
            } else {
                warn!("Not JSON and < 6 bytes; ignoring (len={})", data.len());
            }
        }
    });
}

fn write_serial_bytes(
    port: &Arc<StdMutex<Box<dyn serialport::SerialPort>>>,
    bytes: &[u8],
) -> std::io::Result<()> {
    let mut guard = port
        .lock()
        .map_err(|_| std::io::Error::new(std::io::ErrorKind::Other, "serial mutex poisoned"))?;
    guard.write_all(bytes)?;
    guard.flush()?;
    Ok(())
}

fn parse_json_grid(bytes: &[u8]) -> Option<Vec<Vec<f32>>> {
    if let Ok(v) = serde_json::from_slice::<Vec<Vec<f32>>>(bytes) {
        if is_rectangular(&v) {
            return Some(v);
        }
    }

    #[derive(serde::Deserialize)]
    struct Obj {
        grid: Vec<Vec<f32>>,
    }

    if let Ok(obj) = serde_json::from_slice::<Obj>(bytes) {
        if is_rectangular(&obj.grid) {
            return Some(obj.grid);
        }
    }

    None
}

fn is_rectangular(v: &Vec<Vec<f32>>) -> bool {
    if v.is_empty() {
        return true;
    }
    let cols = v[0].len();
    v.iter().all(|r| r.len() == cols)
}

fn grid_to_node_states_4(grid: &Vec<Vec<f32>>) -> [u8; 6] {
    let mut states = [4u8; 6];

    if grid.is_empty() || grid[0].is_empty() {
        return states;
    }

    let rows = grid.len().min(2);
    let cols = grid[0].len().min(3);

    for r in 0..rows {
        for c in 0..cols {
            let idx = r * 3 + c;
            let mut v = grid[r][c];
            if v.is_nan() {
                v = 0.0;
            }
            v = v.clamp(0.0, 1.0);

            states[idx] = if v < 0.25 {
                4
            } else if v < 0.5 {
                3
            } else if v < 0.75 {
                2
            } else {
                1
            };
        }
    }

    states
}