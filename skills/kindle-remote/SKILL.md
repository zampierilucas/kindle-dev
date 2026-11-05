---
name: kindle-remote
description: Drive the Kindle screen over SSH — screenshot, screen-record, tap, swipe, scroll. Use to visually verify Kindle UI (BTManager WAF app, KOReader, native framework), confirm a change actually renders, or automate touch interaction on the device. Backed by kindle-remote.py (host) + xtap.py (on-device X11 XTEST).
---

# Kindle Remote

Host-side remote control for the Kindle over the `kindle` SSH alias. Lets you *see* the device screen (read `/dev/fb0`) and *drive* it (tap / swipe / scroll), so you can verify UI changes instead of guessing from logs.

- **Driver script (host):** `scripts/kindle-remote.py` in this repo
- **Tap helper (on device):** `scripts/xtap.py`, copied to the Kindle (default `/mnt/us/kindle_hid_passthrough/xtap.py`, override with `KINDLE_XTAP`) — pure-Python X11 XTEST injection via `/tmp/.X11-unix/X0`, no Xlib needed.

Run everything as `python3 <repo>/scripts/kindle-remote.py <command>`. `KINDLE_HOST` (default `kindle`) is the SSH host, `KINDLE_PYTHON` the Python on the device.

## Commands

| Command | What it does |
|---|---|
| `screenshot [out.png]` | Capture screen → PNG (default `/tmp/kindle-screenshot.png`) |
| `record SECONDS [out.mp4]` | Record screen to mp4 (polls framebuffer ~4 fps, ffmpeg) |
| `record-gif SECONDS [out.gif]` | Record screen to gif |
| `tap X Y` | Tap absolute pixel coords (XTEST) |
| `tap-pct X% Y%` | Tap at percentage of screen — prefer this, resolution-independent |
| `swipe X1 Y1 X2 Y2` | Swipe gesture (evdev `/dev/input/event1`) |
| `scroll-up` / `scroll-down` | Scroll content (a vertical swipe) |
| `screen-size` | Print `WIDTHxHEIGHT` (e.g. `1072x1448`) |
| `info` | Dump `/proc/bus/input/devices` |

## Visual-verification workflow

This is the main use — confirm something renders, don't just trust logs:

1. `python3 .../kindle-remote.py screenshot /tmp/shot.png`
2. **Read `/tmp/shot.png`** with the Read tool to actually look at it.
3. Decide the tap target. Use `tap-pct` (e.g. a button ~80% down, centered → `tap-pct 50 80`), or read exact pixels off the screenshot and `tap X Y`.
4. Tap, wait a beat for the e-ink refresh, screenshot again, Read again to confirm the new state.

For a flow with animation/transitions, `record 5 /tmp/clip.mp4` and inspect frames.

## Key facts / gotchas

- **Screen is 1072x1448** on this PW-class Kindle; framebuffer is **8-bit grayscale** (PIL mode `"L"`), pixels 1:1 with the framebuffer. `screen_size()` reads it live from X11 and falls back to `1072x1448`.
- **Taps need X11/Mesquite in the foreground.** XTEST injects into the native framework (`/tmp/.X11-unix/X0`). If a non-X app owns the screen, taps may not land where expected.
- **e-ink is slow** — leave ~0.5–1s between a tap and the confirming screenshot so the panel has refreshed.
- **Swipe/scroll use evdev** (`/dev/input/event1`, BTN_TOUCH 330, ABS_MT slots), a different path than taps.
- **Host deps:** Pillow (`PIL`) and `ffmpeg` (for record). The `kindle` SSH alias must reach the device (if the Kindle sleeps, Wi-Fi drops; wake it first). On-device taps need `xtap.py` present at `/mnt/us/kindle_hid_passthrough/xtap.py`.
- **Framebuffer reads are ~1.5 MB** each over SSH; over a flaky relay a `screenshot`/`record` can stall — retry if it hangs.

## Pairing with other work

Handy right after `just deploy` on kindle-hid-passthrough: screenshot the BTManager WAF app to confirm it launched and rendered, tap through its scan/pair UI, or verify KOReader picks up an input device — all without physical access to the Kindle.
