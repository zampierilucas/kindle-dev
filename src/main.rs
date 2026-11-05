mod fb;
mod x11;

use evdev::{AbsoluteAxisType, Device, EventType, InputEvent, InputEventKind, Key};
use std::io::{self, IsTerminal, Write};
use std::process::exit;
use std::thread::sleep;
use std::time::{Duration, Instant};

const USAGE: &str = "\
usage: kindle-dev COMMAND

  screenshot                 write a PNG of the screen to stdout
  record SECONDS [FPS]       write PNG frames to stdout (default 4 fps), pipe into ffmpeg
  screen-size                print WIDTHxHEIGHT
  tap X Y                    tap pixel coordinates through X11 (native Kindle UI only)
  tap-pct X Y                tap at a percentage of the screen
  swipe X1 Y1 X2 Y2          swipe on the touchscreen through evdev (works in KOReader)
  scroll-up | scroll-down    vertical swipe across the middle of the screen
  key KEY [DEVICE]           press and release a key through evdev
  key-down KEY [DEVICE]      press only
  key-up KEY [DEVICE]        release only
  devices                    list input devices
  events DEVICE              print input events from a device until Ctrl+C

KEY is a Linux input name (KEY_ENTER, BTN_SOUTH, or just enter) or a number.
DEVICE is a path like /dev/input/event2 or just event2. Without it, key
commands pick the non-touchscreen device with the most keys that reports KEY.";

type Res = Result<(), Box<dyn std::error::Error>>;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    if let Err(e) = run(&args) {
        eprintln!("kindle-dev: {e}");
        exit(1);
    }
}

fn num<T: std::str::FromStr>(s: &str) -> Result<T, String> {
    s.parse().map_err(|_| format!("not a number: {s}"))
}

fn run(args: &[&str]) -> Res {
    match args {
        ["screenshot"] => {
            let out = png_stdout()?;
            fb::Framebuffer::open()?.write_png(out)?;
        }
        ["record", secs, rest @ ..] if rest.len() <= 1 => {
            let fps: f64 = rest.first().map_or(Ok(4.0), |f| num(f))?;
            let frames = (num::<f64>(secs)? * fps) as usize;
            let mut fb = fb::Framebuffer::open()?;
            let mut out = png_stdout()?;
            for _ in 0..frames {
                let start = Instant::now();
                fb.write_png(&mut out)?;
                out.flush()?;
                if let Some(left) = Duration::from_secs_f64(1.0 / fps).checked_sub(start.elapsed()) {
                    sleep(left);
                }
            }
        }
        ["screen-size"] => {
            let fb = fb::Framebuffer::open()?;
            println!("{}x{}", fb.width, fb.height);
        }
        ["tap", x, y] => x11::X11::connect()?.tap(num(x)?, num(y)?)?,
        ["tap-pct", x, y] => {
            let mut x11 = x11::X11::connect()?;
            let x = (x11.width as f64 * num::<f64>(x)? / 100.0) as i16;
            let y = (x11.height as f64 * num::<f64>(y)? / 100.0) as i16;
            x11.tap(x, y)?;
        }
        ["swipe", x1, y1, x2, y2] => swipe(num(x1)?, num(y1)?, num(x2)?, num(y2)?)?,
        ["scroll-up" | "scroll-down"] => {
            let fb = fb::Framebuffer::open()?;
            let (x, top, bottom) = (fb.width as i32 / 2, fb.height as i32 / 4, fb.height as i32 * 3 / 4);
            if args[0] == "scroll-up" {
                swipe(x, bottom, x, top)?;
            } else {
                swipe(x, top, x, bottom)?;
            }
        }
        [cmd @ ("key" | "key-down" | "key-up"), key, dev @ ..] if dev.len() <= 1 => {
            let code = parse_key(key)?;
            let mut device = match dev.first() {
                Some(d) => open_device(d)?,
                None => keyboard(code)?,
            };
            let values: &[i32] = match *cmd {
                "key-down" => &[1],
                "key-up" => &[0],
                _ => &[1, 0],
            };
            for &v in values {
                device.send_events(&[
                    InputEvent::new(EventType::KEY, code.code(), v),
                    InputEvent::new(EventType::SYNCHRONIZATION, 0, 0),
                ])?;
                sleep(Duration::from_millis(30));
            }
        }
        ["devices"] => {
            let mut devices: Vec<_> = evdev::enumerate().collect();
            devices.sort_by(|a, b| a.0.cmp(&b.0));
            for (path, dev) in devices {
                println!("{}  {}", path.display(), dev.name().unwrap_or("?"));
            }
        }
        ["events", dev] => {
            let mut device = open_device(dev)?;
            println!("{}", device.name().unwrap_or("?"));
            loop {
                for ev in device.fetch_events()? {
                    match ev.kind() {
                        InputEventKind::Synchronization(_) => {}
                        kind => println!("{kind:?} {}", ev.value()),
                    }
                }
            }
        }
        _ => {
            eprintln!("{USAGE}");
            exit(2);
        }
    }
    Ok(())
}

fn png_stdout() -> Result<io::StdoutLock<'static>, String> {
    let out = io::stdout();
    if out.is_terminal() {
        return Err("refusing to write PNG data to a terminal, redirect stdout to a file".into());
    }
    Ok(out.lock())
}

fn open_device(d: &str) -> Result<Device, String> {
    let path = if d.starts_with('/') { d.to_string() } else { format!("/dev/input/{d}") };
    Device::open(&path).map_err(|e| format!("{path}: {e}"))
}

fn parse_key(s: &str) -> Result<Key, String> {
    if let Ok(n) = s.parse() {
        return Ok(Key::new(n));
    }
    let up = s.to_uppercase();
    [up.clone(), format!("KEY_{up}"), format!("BTN_{up}")]
        .iter()
        .find_map(|name| name.parse().ok())
        .ok_or_else(|| format!("unknown key {s}, see linux/input-event-codes.h for names"))
}

fn keyboard(key: Key) -> Result<Device, String> {
    evdev::enumerate()
        .map(|(_, d)| d)
        .filter(|d| d.supported_absolute_axes().is_none())
        .filter(|d| d.supported_keys().is_some_and(|k| k.contains(key)))
        .max_by_key(|d| d.supported_keys().map_or(0, |k| k.iter().count()))
        .ok_or_else(|| format!("no input device reports {key:?}, pass DEVICE"))
}

fn touchscreen() -> Result<Device, String> {
    evdev::enumerate()
        .map(|(_, d)| d)
        .find(|d| {
            d.supported_absolute_axes()
                .is_some_and(|a| a.contains(AbsoluteAxisType::ABS_MT_POSITION_X))
        })
        .ok_or_else(|| "no multitouch input device found".into())
}

fn swipe(x1: i32, y1: i32, x2: i32, y2: i32) -> Res {
    const STEPS: i32 = 10;
    let mut touch = touchscreen()?;
    let abs = |axis: AbsoluteAxisType, v| InputEvent::new(EventType::ABSOLUTE, axis.0, v);
    let syn = InputEvent::new(EventType::SYNCHRONIZATION, 0, 0);
    let btn_touch = |v| InputEvent::new(EventType::KEY, Key::BTN_TOUCH.code(), v);
    for i in 0..=STEPS {
        let mut evs = vec![
            abs(AbsoluteAxisType::ABS_MT_POSITION_X, x1 + (x2 - x1) * i / STEPS),
            abs(AbsoluteAxisType::ABS_MT_POSITION_Y, y1 + (y2 - y1) * i / STEPS),
            abs(AbsoluteAxisType::ABS_MT_TOUCH_MAJOR, 10),
            abs(AbsoluteAxisType::ABS_MT_TRACKING_ID, 0),
        ];
        if i == 0 {
            evs.push(btn_touch(1));
        }
        evs.push(syn);
        touch.send_events(&evs)?;
        sleep(Duration::from_millis(30));
    }
    touch.send_events(&[abs(AbsoluteAxisType::ABS_MT_TRACKING_ID, -1), btn_touch(0), syn])?;
    Ok(())
}
