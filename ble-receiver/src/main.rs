// https://docs.rs/bluer/latest/src/le_advertise/le_advertise.rs.html

use std::time::Duration;
use bluer::adv::Advertisement;
use tokio::{
    io::{AsyncBufReadExt, BufReader},
    time::sleep
};

const SRV_UUID: &str = "8b322909-2d3b-447b-a4d5-dfe0c009ec5a";

const DEVICE_NAME: &str = "WHV Haptic Feedback Device";

#[tokio::main]
async fn main() -> bluer::Result<()> {
    env_logger::init();
    let session = bluer::Session::new().await?;
    let adapter = session.default_adapter().await?;
    adapter.set_powered(true).await?;

    println!("Advertising on Bluetooth adapter {} with address {}", adapter.name(), adapter.address().await?);
    let le_advertisement = Advertisement {
        advertisement_type: bluer::adv::Type::Peripheral,
        service_uuids: vec![SRV_UUID.parse().unwrap()].into_iter().collect(),
        discoverable: Some(true),
        local_name: Some(DEVICE_NAME.to_string()),
        system_includes: vec![bluer::adv::Feature::Appearance, bluer::adv::Feature::LocalName].into_iter().collect(),
        ..Default::default()
    };
    println!("{:?}", &le_advertisement);
    let handle = adapter.advertise(le_advertisement).await?;

    println!("Press enter to quit");
    let stdin = BufReader::new(tokio::io::stdin());
    let mut lines = stdin.lines();
    let _ = lines.next_line().await;

    println!("Removing advertisement");
    drop(handle);
    sleep(Duration::from_secs(1)).await;

    Ok(())
}
