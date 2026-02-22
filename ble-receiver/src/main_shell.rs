use anyhow::Result;
use esp_idf_hal::delay::Ets;
use esp_idf_hal::gpio::{AnyOutputPin, Output, PinDriver};
use esp_idf_svc::bt::ble::gap::{AdvConfiguration, AdvertisingData};
use esp_idf_svc::bt::ble::gatt::server::{
    AttributeValue, GattCharacteristic, GattServer, GattService, WriteEvent,
};
use esp_idf_svc::bt::ble::{Ble, BleDevice};
use esp_idf_svc::log::EspLogger;
use log::{info, warn};
use std::sync::{Arc, Mutex};

const SERVICE_UUID: [u8; 16] = *b"\x5a\xec\x09\xc0\xe0\xdf\xd5\xa4\x7b\x44\x3b\x2d\x09\x29\x32\x8b";
const WRITE_CHAR_UUID: [u8; 16] = *b"\x5a\xec\x09\xc0\xe0\xdf\xd5\xa4\x7b\x44\x3b\x2d\x0a\x29\x32\x8b";

#[derive(Clone, Copy, Debug)]
enum NodeCmd {
    Hold,
    Inflate,
    Deflate,
}

impl NodeCmd {
    fn from_3bit(v: u8) -> NodeCmd {
        match v & 0b111 {
            0b001 => NodeCmd::Inflate,
            0b010 => NodeCmd::Deflate,
            _ => NodeCmd::Hold,
        }
    }

    fn to_state_bits(self) -> (bool, bool) {
        match self {
            NodeCmd::Hold => (false, false),
            NodeCmd::Inflate => (true, false),
            NodeCmd::Deflate => (false, true),
        }
    }
}

struct GpioMuxDriver {
    s0: PinDriver<'static, AnyOutputPin, Output>,
    s1: PinDriver<'static, AnyOutputPin, Output>,
    s2: PinDriver<'static, AnyOutputPin, Output>,
    st_a: PinDriver<'static, AnyOutputPin, Output>,
    st_b: PinDriver<'static, AnyOutputPin, Output>,
}

impl GpioMuxDriver {
    fn new(
        mux_s0: AnyOutputPin,
        mux_s1: AnyOutputPin,
        mux_s2: AnyOutputPin,
        state_a: AnyOutputPin,
        state_b: AnyOutputPin,
    ) -> Result<Self> {
        let mut s0 = PinDriver::output(mux_s0)?;
        let mut s1 = PinDriver::output(mux_s1)?;
        let mut s2 = PinDriver::output(mux_s2)?;
        let mut st_a = PinDriver::output(state_a)?;
        let mut st_b = PinDriver::output(state_b)?;

        s0.set_low()?;
        s1.set_low()?;
        s2.set_low()?;
        st_a.set_low()?;
        st_b.set_low()?;

        Ok(Self { s0, s1, s2, st_a, st_b })
    }

    fn select_node(&mut self, idx: u8) -> Result<()> {
        if (idx & 0b001) != 0 { self.s0.set_high()? } else { self.s0.set_low()? }
        if (idx & 0b010) != 0 { self.s1.set_high()? } else { self.s1.set_low()? }
        if (idx & 0b100) != 0 { self.s2.set_high()? } else { self.s2.set_low()? }
        Ok(())
    }

    fn set_cmd(&mut self, cmd: NodeCmd) -> Result<()> {
        let (a, b) = cmd.to_state_bits();
        if a { self.st_a.set_high()? } else { self.st_a.set_low()? }
        if b { self.st_b.set_high()? } else { self.st_b.set_low()? }
        Ok(())
    }

    fn apply_frame(&mut self, cmds: [NodeCmd; 8]) -> Result<()> {
        for i in 0u8..8 {
            self.select_node(i)?;
            self.set_cmd(cmds[i as usize])?;
            Ets::delay_us(10);
        }
        Ok(())
    }
}

fn unpack_frame24(payload3: &[u8]) -> [NodeCmd; 8] {
    let bits: u32 = (payload3[0] as u32) | ((payload3[1] as u32) << 8) | ((payload3[2] as u32) << 16);
    let mut cmds = [NodeCmd::Hold; 8];
    for i in 0..8 {
        let v = ((bits >> (i * 3)) & 0x7) as u8;
        cmds[i] = NodeCmd::from_3bit(v);
    }
    cmds
}

fn strengths8_to_cmds(payload8: &[u8]) -> [NodeCmd; 8] {
    let mut cmds = [NodeCmd::Hold; 8];
    for i in 0..8 {
        let v = payload8[i];
        cmds[i] = if v < 85 {
            NodeCmd::Hold
        } else if v < 170 {
            NodeCmd::Inflate
        } else {
            NodeCmd::Deflate
        };
    }
    cmds
}

fn main() -> Result<()> {
    EspLogger::initialize_default();

    let peripherals = esp_idf_hal::peripherals::Peripherals::take()?;
    let pins = peripherals.pins;

    let mux_s0 = pins.gpio17.into_output()?.downgrade();
    let mux_s1 = pins.gpio16.into_output()?.downgrade();
    let mux_s2 = pins.gpio4.into_output()?.downgrade();
    let state_a = pins.gpio18.into_output()?.downgrade();
    let state_b = pins.gpio19.into_output()?.downgrade();

    let driver = Arc::new(Mutex::new(GpioMuxDriver::new(mux_s0, mux_s1, mux_s2, state_a, state_b)?));

    let ble = Ble::new()?;
    let dev = BleDevice::new(&ble)?;
    let mut gatt = GattServer::new(dev.clone())?;

    let driver_for_cb = driver.clone();

    let write_char = GattCharacteristic::new_write(
        WRITE_CHAR_UUID,
        AttributeValue::new(vec![]),
        move |evt: WriteEvent| {
            let data = evt.data();
            let cmds_opt = match data.len() {
                3 => Some(unpack_frame24(data)),
                8 => Some(strengths8_to_cmds(data)),
                _ => None,
            };

            if let Some(cmds) = cmds_opt {
                if let Ok(mut d) = driver_for_cb.lock() {
                    let _ = d.apply_frame(cmds);
                }
            } else {
                warn!("Unexpected payload length: {}", data.len());
            }

            Ok(())
        },
    );

    let service = GattService::new_primary(SERVICE_UUID, vec![write_char]);
    gatt.register_service(service)?;
    gatt.start()?;

    let mut adv_data = AdvertisingData::new();
    adv_data.set_name(Some("WHV-ESP32".into()));
    adv_data.add_service_uuid(SERVICE_UUID);

    dev.gap().advertise(AdvConfiguration::default(), adv_data, None)?;

    info!("BLE advertising as WHV-ESP32. Write 3B(frame24) or 8B(strengths).");

    loop {
        std::thread::sleep(std::time::Duration::from_secs(60));
    }
}
