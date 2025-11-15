use bluer::{
    adv::Advertisement,
    gatt::local::{
        Application, Characteristic, CharacteristicRead, CharacteristicWrite, CharacteristicWriteMethod,
        Service,
    },
    Uuid,
};
use futures::FutureExt;
use std::{collections::BTreeSet, sync::Arc, time::Duration};
use tokio::{sync::Mutex, time::sleep};

use serialport;
use std::io::Write;
use serde::Deserialize;
use serde_json;

const SRV_UUID: Uuid = Uuid::from_u128(0x8b322909_2d3b_447b_a4d5_dfe0c009ec5a);
const WR_CHAR_UUID: Uuid = Uuid::from_u128(0x8b32290a_2d3b_447b_a4d5_dfe0c009ec5a);
const INFO_UUID:   Uuid = Uuid::from_u128(0x8b32290c_2d3b_447b_a4d5_dfe0c009ec5a);

#[tokio::main(flavor = "current_thread")]
async fn main() {
    env_logger::init();

    let session = bluer::Session::new().await.expect("create bluer session");
    let adapter = session
        .default_adapter()
        .await
        .expect("get default adapter");
    adapter
        .set_powered(true)
        .await
        .expect("power on adapter");

    let mut svc = BTreeSet::new();
    svc.insert(SRV_UUID);
    let adv = Advertisement {
        service_uuids: svc,
        discoverable: Some(true),
        local_name: Some("WHV Haptic Receiver".to_string()),
        ..Default::default()
    };
    let _adv_handle = adapter.advertise(adv).await.expect("start advertising");

    let last_payload: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(Vec::new()));
    let last_payload_for_write = Arc::clone(&last_payload);
    let last_payload_for_read  = Arc::clone(&last_payload);

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
                            let last_payload_for_write = Arc::clone(&last_payload_for_write);
                            async move {
                                {
                                    let mut buf = last_payload_for_write.lock().await;
                                    *buf = data.clone();
                                }

                                print!("RX {} bytes: [", data.len());
                                for (i, b) in data.iter().enumerate() {
                                    if i > 0 { print!(" "); }
                                    print!("{:02X}", b);
                                }
                                println!("]");

                                process_payload_and_send_to_feather(&data);
                                
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
                            let last_payload_for_read = Arc::clone(&last_payload_for_read);
                            async move {
                                let len = last_payload_for_read.lock().await.len();
                                let s = format!("WHV Pi5 Receiver v0.1 (last {} bytes)", len);
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

    println!("BLE receiver is up. Write to char {} and I'll log it.", WR_CHAR_UUID);

    loop {
        sleep(Duration::from_secs(60)).await;
    }
}

async fn process_payload_and_send_to_feather(data: &[u8]) {
    // If JSON, treat as heatmap and map to 6 states
    if let Some(grid) = parse_json_grid(data) {
        let states = grid_to_node_states_4(&grid);

        if let Ok(mut port) = serialport::new("/dev/ttyACM0", 115200)
        .timeout(Duration::from_millis(50))
        .open()
    {
        let _ = port.write_all(&states);
    }
    return;
}
}

fn parse_json_grid(bytes: &[u8]) -> Option<Vec<Vec<f32>>> {
    serde_json::from_slice::<Vec<Vec<f32>>>(bytes).ok()
}

fn grid_to_node_states_4(grid: &Vec<Vec<f32>>) -> [u8; 6] {
    let mut states = [4u8; 6]; // default all to least pressure

    if grid.is_empty() || grid[0].is_empty() {
        return states;
    }

    // Ensures only 2x3 grid is sent
    let rows = grid.len().min(2);
    let cols = grid[0].len().min(3);

    for r in 0..rows {
        for c in 0..cols {
            let idx = r * 3 + c; // 0..5
            let mut v = grid[r][c];

            if v.is_nan() {
                v = 0.0;
            }
            if v < 0.0 {
                v = 0.0;
            }
            if v > 1.0 {
                v = 1.0;
            }

            let state = if v < 0.25 {
                4u8   // far, least pressure
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