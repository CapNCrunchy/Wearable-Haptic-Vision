use bluer::{
    adv::Advertisement,
    gatt::local::{
        Application, Characteristic, CharacteristicRead, CharacteristicWrite,
        CharacteristicWriteMethod, Service,
    },
    Uuid,
};
use futures::FutureExt;
use log::{info, warn};
use rppal::gpio::{Gpio, OutputPin};
use serde::Deserialize;
use std::{
    collections::{BTreeSet, VecDeque},
    sync::Arc,
    time::Duration,
};
use tokio::{
    sync::{mpsc, Mutex},
    time::{sleep},
};

const SRV_UUID: Uuid = Uuid::from_u128(0x8b322909_2d3b_447b_a4d5_dfe0c009ec5a);
const WR_CHAR_UUID: Uuid = Uuid::from_u128(0x8b32290a_2d3b_447b_a4d5_dfe0c009ec5a);
const INFO_UUID: Uuid = Uuid::from_u128(0x8b32290c_2d3b_447b_a4d5_dfe0c009ec5a);

const HISTORY_MAX: usize = 8;

const MUX_S0: u8 = 17;
const MUX_S1: u8 = 27;
const MUX_S2: u8 = 22;

const STATE_A: u8 = 23;
const STATE_B: u8 = 24;

const PIN_ENABLE: Option<u8> = None;
const PIN_LATCH: Option<u8> = None;

#[derive(Clone, Copy, Debug)]
struct VerticalWindow {
    top_norm: f32,
    bottom_norm: f32,
}

#[derive(Clone, Debug)]
struct GridFrame {
    rows: usize,
    cols: usize,
    data: Vec<Vec<f32>>,
}

#[derive(Clone, Copy, Debug)]
enum NodeCmd {
    Hold,
    Inflate,
    Deflate,
}

impl NodeCmd {
    fn to_3bit(self) -> u32 {
        match self {
            NodeCmd::Hold => 0b000,
            NodeCmd::Inflate => 0b001,
            NodeCmd::Deflate => 0b010,
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

#[derive(Default)]
struct AppState {
    last_raw: Vec<u8>,
    last_grid: Option<GridFrame>,
    history: VecDeque<GridFrame>,
    window: VerticalWindow,
    last_frame24: Option<[u8; 3]>,
}

struct GpioMuxDriver {
    s0: OutputPin,
    s1: OutputPin,
    s2: OutputPin,
    st_a: OutputPin,
    st_b: OutputPin,
    enable: Option<OutputPin>,
    latch: Option<OutputPin>,
}

impl GpioMuxDriver {
    fn new() -> anyhow::Result<Self> {
        let gpio = Gpio::new()?;

        let mut s0 = gpio.get(MUX_S0)?.into_output();
        let mut s1 = gpio.get(MUX_S1)?.into_output();
        let mut s2 = gpio.get(MUX_S2)?.into_output();
        let mut st_a = gpio.get(STATE_A)?.into_output();
        let mut st_b = gpio.get(STATE_B)?.into_output();

        s0.set_low();
        s1.set_low();
        s2.set_low();
        st_a.set_low();
        st_b.set_low();

        let enable = match PIN_ENABLE {
            Some(p) => {
                let mut pin = gpio.get(p)?.into_output();
                pin.set_high();
                Some(pin)
            }
            None => None,
        };

        let latch = match PIN_LATCH {
            Some(p) => {
                let mut pin = gpio.get(p)?.into_output();
                pin.set_low();
                Some(pin)
            }
            None => None,
        };

        Ok(Self {
            s0,
            s1,
            s2,
            st_a,
            st_b,
            enable,
            latch,
        })
    }

    #[inline]
    fn select_node(&mut self, idx: u8) {
        if (idx & 0b001) != 0 {
            self.s0.set_high()
        } else {
            self.s0.set_low()
        }
        if (idx & 0b010) != 0 {
            self.s1.set_high()
        } else {
            self.s1.set_low()
        }
        if (idx & 0b100) != 0 {
            self.s2.set_high()
        } else {
            self.s2.set_low()
        }
    }

    #[inline]
    fn set_cmd(&mut self, cmd: NodeCmd) {
        let (a, b) = cmd.to_state_bits();
        if a {
            self.st_a.set_high()
        } else {
            self.st_a.set_low()
        }
        if b {
            self.st_b.set_high()
        } else {
            self.st_b.set_low()
        }
    }

    #[inline]
    fn pulse_latch_if_present(&mut self) {
        if let Some(l) = self.latch.as_mut() {
            l.set_high();
            l.set_low();
        }
    }

    fn apply_frame(&mut self, cmds: [NodeCmd; 8]) {
        for i in 0u8..8 {
            self.select_node(i);
            self.set_cmd(cmds[i as usize]);
            self.pulse_latch_if_present();
        }
    }
}

#[derive(Deserialize)]
struct ObjGrid {
    grid: Vec<Vec<f32>>,
}

fn parse_json_grid(bytes: &[u8]) -> Option<Vec<Vec<f32>>> {
    if let Ok(v) = serde_json::from_slice::<Vec<Vec<f32>>>(bytes) {
        if is_rectangular(&v) {
            return Some(v);
        }
    }
    if let Ok(obj) = serde_json::from_slice::<ObjGrid>(bytes) {
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

fn grid_to_8_node_strengths(grid: &Vec<Vec<f32>>, window: VerticalWindow) -> [f32; 8] {
    let mut out = [0.0f32; 8];
    if grid.is_empty() || grid[0].is_empty() {
        return out;
    }

    let rows = grid.len();
    let cols = grid[0].len();

    let top = (window.top_norm.clamp(0.0, 1.0) * (rows as f32 - 1.0)).round() as isize;
    let bot = (window.bottom_norm.clamp(0.0, 1.0) * (rows as f32 - 1.0)).round() as isize;
    let (r0, r1) = if top <= bot { (top, bot) } else { (bot, top) };

    let r0 = r0.max(0) as usize;
    let r1 = r1.min((rows - 1) as isize) as usize;

    for node in 0..8 {
        let c0 = (node * cols) / 8;
        let c1 = ((node + 1) * cols) / 8;

        let mut sum = 0.0f32;
        let mut n = 0usize;

        for r in r0..=r1 {
            for c in c0..c1 {
                let mut v = grid[r][c];
                if v.is_nan() {
                    v = 0.0;
                }
                v = v.clamp(0.0, 1.0);
                sum += v;
                n += 1;
            }
        }

        out[node] = if n == 0 { 0.0 } else { sum / n as f32 };
    }

    out
}

fn strengths_to_cmds(strengths: [f32; 8]) -> [NodeCmd; 8] {
    let mut cmds = [NodeCmd::Hold; 8];
    for i in 0..8 {
        let v = strengths[i];
        cmds[i] = if v < 0.33 {
            NodeCmd::Hold
        } else if v < 0.66 {
            NodeCmd::Inflate
        } else {
            NodeCmd::Deflate
        };
    }
    cmds
}

fn pack_frame24(cmds: [NodeCmd; 8]) -> [u8; 3] {
    let mut bits: u32 = 0;
    for i in 0..8 {
        bits |= (cmds[i].to_3bit() & 0x7) << (i * 3);
    }
    [
        (bits & 0xFF) as u8,
        ((bits >> 8) & 0xFF) as u8,
        ((bits >> 16) & 0xFF) as u8,
    ]
}

fn spawn_worker(
    mut rx: mpsc::UnboundedReceiver<Vec<u8>>,
    state: Arc<Mutex<AppState>>,
    gpio: Arc<Mutex<GpioMuxDriver>>,
) {
    tokio::spawn(async move {
        while let Some(data) = rx.recv().await {
            {
                let mut st = state.lock().await;
                st.last_raw = data.clone();
            }

            if !data.is_empty() && (data[0] == b'{' || data[0] == b'[') {
                if let Some(grid) = parse_json_grid(&data) {
                    let gf = GridFrame {
                        rows: grid.len(),
                        cols: grid.get(0).map(|r| r.len()).unwrap_or(0),
                        data: grid.clone(),
                    };

                    let window = {
                        let mut st = state.lock().await;
                        st.last_grid = Some(gf.clone());
                        st.history.push_back(gf);
                        while st.history.len() > HISTORY_MAX {
                            st.history.pop_front();
                        }
                        st.window
                    };

                    let strengths = grid_to_8_node_strengths(&grid, window);
                    let cmds = strengths_to_cmds(strengths);
                    let frame24 = pack_frame24(cmds);

                    {
                        let mut st = state.lock().await;
                        st.last_frame24 = Some(frame24);
                    }

                    {
                        let mut driver = gpio.lock().await;
                        driver.apply_frame(cmds);
                    }

                    continue;
                } else {
                    warn!("JSON detected but parse failed");
                    continue;
                }
            }

            warn!("Non-JSON payload ignored (len={})", data.len());
        }
    });
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::init();

    let state = Arc::new(Mutex::new(AppState {
        window: VerticalWindow {
            top_norm: 0.0,
            bottom_norm: 1.0,
        },
        ..Default::default()
    }));

    let gpio = Arc::new(Mutex::new(GpioMuxDriver::new()?));

    let (tx, rx) = mpsc::unbounded_channel::<Vec<u8>>();
    spawn_worker(rx, Arc::clone(&state), Arc::clone(&gpio));

    let session = bluer::Session::new().await?;
    let adapter = session.default_adapter().await?;
    adapter.set_powered(true).await?;

    let mut svc = BTreeSet::new();
    svc.insert(SRV_UUID);

    let adv = Advertisement {
        service_uuids: svc,
        discoverable: Some(true),
        local_name: Some("WHV Haptic Receiver (GPIO)".to_string()),
        ..Default::default()
    };
    let _adv_handle = adapter.advertise(adv).await?;

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
                                let frame = st
                                    .last_frame24
                                    .map(|b| format!("{:02X}{:02X}{:02X}", b[2], b[1], b[0]))
                                    .unwrap_or_else(|| "none".into());

                                let s = format!(
                                    "WHV GPIO | last_raw={} | last_grid={}x{} | history={} | frame24={}",
                                    raw_len,
                                    rows,
                                    cols,
                                    st.history.len(),
                                    frame
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

    let _app_handle = adapter.serve_gatt_application(app).await?;
    info!("BLE up. Driving GPIO mux/state pins.");

    loop {
        sleep(Duration::from_secs(60)).await;
    }
}