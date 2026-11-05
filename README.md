# kindle-dev

One static binary for a jailbroken Kindle that lets you, or an AI agent, see the screen and drive it over SSH. Screenshot, record, tap, swipe, inject keys and read input events, with nothing else to install on the device.

## Install

Grab `kindle-dev` from the releases, or build it.

```sh
rustup target add armv7-unknown-linux-musleabihf
cargo build --release --target armv7-unknown-linux-musleabihf
scp target/armv7-unknown-linux-musleabihf/release/kindle-dev kindle:/mnt/us/kindle-dev
```

## Usage

```sh
ssh kindle /mnt/us/kindle-dev screenshot > shot.png
ssh kindle /mnt/us/kindle-dev tap-pct 50 80
ssh kindle /mnt/us/kindle-dev swipe 850 700 200 700
ssh kindle /mnt/us/kindle-dev key enter
ssh kindle /mnt/us/kindle-dev events event1
```

| Command | What it does |
|---|---|
| `screenshot` | Write a PNG of the screen to stdout |
| `record SECONDS [FPS]` | Write PNG frames to stdout, 4 fps by default |
| `screen-size` | Print `WIDTHxHEIGHT` |
| `tap X Y` | Tap pixel coordinates through X11 |
| `tap-pct X Y` | Tap at a percentage of the screen |
| `swipe X1 Y1 X2 Y2` | Swipe on the touchscreen through evdev |
| `scroll-up`, `scroll-down` | Vertical swipe across the middle of the screen |
| `key KEY [DEVICE]` | Press and release a key, `key-down` and `key-up` for one half |
| `devices` | List input devices |
| `events DEVICE` | Print input events until interrupted |

KEY is a Linux input name (`KEY_ENTER`, `BTN_SOUTH`, or just `enter`) or a number. Without DEVICE, `key` picks the device that reports that key.

Record to video:

```sh
ssh kindle /mnt/us/kindle-dev record 5 | ffmpeg -f image2pipe -framerate 4 -i - \
  -c:v libx264 -pix_fmt yuv420p -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' clip.mp4
```

## With an AI agent

Tell your agent the commands above. The loop that works is to take a screenshot, look at it, tap or swipe, wait a second for the e-ink refresh, and take another screenshot to confirm.

## Things to know

- Taps go through X11, so they only reach the native Kindle UI. KOReader reads evdev directly, so use `swipe` or `key` against it.
- Swipe coordinates are sent to the touchscreen as screen pixels, which matches current Kindles.
- KOReader grabs the touchscreen, so `events` on it shows nothing while KOReader runs, even though KOReader still gets the swipes.
- Framebuffers with 8 and 32 bits per pixel work. Old 4 bit Kindles (K3, K4) do not.

## License

GPL-3.0
