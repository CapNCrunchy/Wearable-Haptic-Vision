use bluer::Uuid;
use bluer::gatt::local::{Application, Characteristic, CharacteristicNotify, Service};
use futures::future;
use std::sync::{Arc, Mutex};

const SRV_UUID: &str  = "8b322909-2d3b-447b-a4d5-dfe0c009ec5a";
const CMD_UUID: &str  = "8b32290a-2d3b-447b-a4d5-dfe0c009ec5a";
const STAT_UUID: &str = "8b32290b-2d3b-447b-a4d5-dfe0c009ec5a";
const INFO_UUID: &str = "8b32290c-2d3b-447b-a4d5-dfe0c009ec5a";

#[tokio::main]
async fn main() -> bluer::Result<()> {
    env_logger::init();

    let session = bluer::Session::new().await?;
    let adapter = session.default_adapter().await?;
    adapter.set_powered(true).await?;

    let srv_uuid  = Uuid::parse_str(SRV_UUID).unwrap();
    let cmd_uuid  = Uuid::parse_str(CMD_UUID).unwrap();
    let stat_uuid = Uuid::parse_str(STAT_UUID).unwrap();
    let info_uuid = Uuid::parse_str(INFO_UUID).unwrap();

    let app = Application::new(&session, "/whv").await?;
    let service = Service::new(&app, srv_uuid, /*primary=*/true).await?;

    let status_tx: Arc<Mutex<Option<CharacteristicNotify>>> = Arc::new(Mutex::new(None));

    {
        let ch = Characteristic::new(&service, stat_uuid).await?;
        ch.set_flags(&["notify"]).await?;

        let tx_clone = status_tx.clone();
        ch.on_subscribe(move |notifier| {
            *tx_clone.lock().unwrap() = Some(notifier);
            Box::pin(async move { Ok(()) })
        });

        let tx_clone = status_tx.clone();
        ch.on_unsubscribe(move || {
            *tx_clone.lock().unwrap() = None;
            Box::pin(async move { Ok(()) })
        });
    }
    {
        let ch = Characteristic::new(&service, cmd_uuid).await?;
        ch.set_flags(&["write", "write-without-response"]).await?;

        let tx_clone = status_tx.clone();
        ch.on_write(move |data: Vec<u8>, _offset| {
            let resp = handle_command_and_make_status(&data);
            if let Some(notifier) = tx_clone.lock().unwrap().as_mut() {
                let _ = notifier.notify(resp);
            }
            Box::pin(async move { Ok(()) })
        });
    }
    {
        let ch = Characteristic::new(&service, info_uuid).await?;
        ch.set_flags(&["read"]).await?;
        ch.on_read(move |_offset| {
            let v = b"WHV Pi5 v0.1";
            Box::pin(async move { Ok(v.to_vec()) })
        });
    }

    app.register().await?;

    use bluer::adv::{Advertisement, AdvertisementType};
    let adv = Advertisement {
        advertisement_type: AdvertisementType::Peripheral,
        service_uuids: vec![srv_uuid],
        local_name: Some("WHV Haptic Feedback Device".into()),
        discoverable: Some(true),
        ..Default::default()
    };
    let _handle = adapter.advertise(adv).await?;

    println!("GATT up; Advertising. Press Ctrl+C to quit.");
    future::pending::<()>().await;
}

fn handle_command_and_make_status(cmd: &[u8]) -> Vec<u8> {
    let opcode = *cmd.get(0).unwrap_or(&0x00);
    vec![0xAA, opcode, 0x00]
}

