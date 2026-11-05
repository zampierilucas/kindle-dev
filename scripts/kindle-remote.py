#!/usr/bin/env python3
"""Kindle Remote - Screen capture and touch injection via SSH.

Usage:
    kindle-remote.py screenshot [output.png]    Capture screen
    kindle-remote.py record SECONDS [out.mp4]   Record screen to mp4 (ffmpeg)
    kindle-remote.py record-gif SECONDS [out.gif]  Record screen to gif
    kindle-remote.py tap X Y                    Tap at pixel coordinates (XTEST)
    kindle-remote.py tap-pct X% Y%              Tap at percentage of screen
    kindle-remote.py swipe X1 Y1 X2 Y2          Swipe gesture (evdev)
    kindle-remote.py scroll-up                   Scroll content up
    kindle-remote.py scroll-down                 Scroll content down
    kindle-remote.py key KEY [DEVICE]            Inject a key press+release (evdev)
    kindle-remote.py key-down KEY [DEVICE]       Inject key press only
    kindle-remote.py key-up KEY [DEVICE]         Inject key release only
    kindle-remote.py keys                        List known key names
    kindle-remote.py screen-size                 Show screen dimensions
    kindle-remote.py info                        Show input device info

Touch uses X11 XTEST (works with Kindle native framework/Mesquite).
Pixel coordinates are 1:1 with framebuffer. Use tap-pct for relative positions.

XTEST taps only reach the native framework. KOReader reads evdev directly, so
use swipe/key against it, not tap.

KEY is a name from `keys` or a raw numeric scancode. DEVICE defaults to the
first /dev/input/event* that advertises EV_KEY and isn't the touchscreen.
"""
import os
import subprocess
import sys

SSH_HOST = os.environ.get("KINDLE_HOST", "kindle")
PYTHON = os.environ.get("KINDLE_PYTHON", "/mnt/us/python3.10-kindle/python3-wrapper.sh")
XTAP = os.environ.get("KINDLE_XTAP", "/mnt/us/kindle_hid_passthrough/xtap.py")
FB_DEV = "/dev/fb0"

_screen_size = None


def ssh(cmd):
    return subprocess.run(["ssh", SSH_HOST, cmd], capture_output=True, timeout=15)


def screen_size():
    """Get screen dimensions from X11 via xtap.py info."""
    global _screen_size
    if _screen_size:
        return _screen_size
    r = ssh(f"{PYTHON} {XTAP} info")
    if r.returncode == 0:
        parts = r.stdout.decode().strip().split("x")
        _screen_size = (int(parts[0]), int(parts[1]))
    else:
        _screen_size = (1072, 1448)  # Kindle PW default
    return _screen_size


def screenshot(output_path="/tmp/kindle-screenshot.png"):
    from PIL import Image
    w, h = screen_size()
    raw = ssh(f"cat {FB_DEV}").stdout
    if len(raw) < w * h:
        print(f"ERROR: framebuffer data too small", file=sys.stderr)
        return None
    Image.frombytes("L", (w, h), raw[:w * h]).save(output_path)
    print(f"Screenshot: {output_path} ({w}x{h})")
    return output_path


def tap(x, y):
    """Tap at absolute pixel coordinates via XTEST."""
    r = ssh(f"{PYTHON} {XTAP} {x} {y}")
    if r.returncode != 0:
        print(f"Tap failed: {r.stderr.decode()}", file=sys.stderr)
    else:
        print(f"Tap ({x}, {y})")


def tap_pct(x_pct, y_pct):
    """Tap at percentage of screen dimensions."""
    w, h = screen_size()
    x = int(w * x_pct / 100)
    y = int(h * y_pct / 100)
    tap(x, y)


def swipe(x1, y1, x2, y2, steps=10, duration=0.3):
    """Swipe via evdev."""
    d = duration / steps
    script = f'''import struct,os,time
def ev(fd,t,c,v):
 now=time.time();s=int(now);u=int((now-s)*1000000)
 os.write(fd,struct.pack("llHHi",s,u,t,c,v))
def syn(fd):ev(fd,0,0,0)
fd=os.open("/dev/input/event1",os.O_WRONLY)
for i in range({steps}+1):
 f=i/{steps};x=int({x1}+({x2}-{x1})*f);y=int({y1}+({y2}-{y1})*f)
 ev(fd,3,0x35,x);ev(fd,3,0x36,y);ev(fd,3,0x30,10);ev(fd,3,0x39,0)
 if i==0:ev(fd,1,330,1)
 syn(fd);time.sleep({d})
ev(fd,3,0x39,-1);ev(fd,1,330,0);syn(fd)
os.close(fd)'''
    ssh(f"""{PYTHON} -c '{script}'""")
    print(f"Swipe ({x1},{y1}) -> ({x2},{y2})")


# Linux input-event-codes, by the name KOReader/FBInk would show. Enough to
# drive a HID passthrough device without looking codes up by hand.
KEYCODES = {
    "esc": 1, "backspace": 14, "tab": 15, "enter": 28, "space": 57,
    "lctrl": 29, "lshift": 42, "rshift": 54, "lalt": 56, "capslock": 58,
    "up": 103, "down": 108, "left": 105, "right": 106,
    "pageup": 104, "pagedown": 109, "home": 102, "end": 107,
    "insert": 110, "delete": 111, "menu": 139, "power": 116,
    "volumedown": 114, "volumeup": 115, "mute": 113,
    "playpause": 164, "nextsong": 163, "previoussong": 165,
    "stopcd": 166, "rewind": 168, "fastforward": 208, "play": 207,
    "brightnessdown": 224, "brightnessup": 225,
    "scrollup": 177, "scrolldown": 178,
    "btnleft": 272, "btnright": 273, "btnmiddle": 274,
    "btna": 304, "btnb": 305, "btnc": 306, "btnx": 307, "btny": 308,
    "btnz": 309, "btntl": 310, "btntr": 311, "btntl2": 312, "btntr2": 313,
    "btnselect": 314, "btnstart": 315, "btnmode": 316,
    "btnthumbl": 317, "btnthumbr": 318,
    "btndpadup": 544, "btndpaddown": 545,
    "btndpadleft": 546, "btndpadright": 547,
}
for _i in range(1, 13):  # F1-F12
    KEYCODES[f"f{_i}"] = 58 + _i
for _i in range(13, 25):  # F13-F24
    KEYCODES[f"f{_i}"] = 170 + _i
for _i in range(1, 10):  # digits
    KEYCODES[str(_i)] = 1 + _i
KEYCODES["0"] = 11
for _i, _c in enumerate("qwertyuiop"):
    KEYCODES[_c] = 16 + _i
for _i, _c in enumerate("asdfghjkl"):
    KEYCODES[_c] = 30 + _i
for _i, _c in enumerate("zxcvbnm"):
    KEYCODES[_c] = 44 + _i


def resolve_keycode(key):
    """Accept a name from KEYCODES or a raw numeric scancode."""
    if str(key).isdigit():
        return int(key)
    code = KEYCODES.get(str(key).lower())
    if code is None:
        raise SystemExit(
            f"Unknown key {key!r}. Use a numeric scancode or one of:\n  "
            + ", ".join(sorted(KEYCODES))
        )
    return code


def key_device():
    """Pick an evdev node that reports keys, skipping the touchscreen."""
    out = ssh("cat /proc/bus/input/devices").stdout.decode(errors="replace")
    best = None
    for block in out.split("\n\n"):
        if "B: KEY=" not in block:
            continue
        handler = None
        for line in block.splitlines():
            if line.startswith("H: Handlers="):
                for tok in line.split("=", 1)[1].split():
                    if tok.startswith("event"):
                        handler = tok
        if not handler:
            continue
        # Touch panels advertise EV_KEY too (BTN_TOUCH); they're not what we want.
        if "B: ABS=" in block:
            continue
        keybits = ""
        for line in block.splitlines():
            if line.startswith("B: KEY="):
                keybits = line.split("=", 1)[1]
        # Prefer the device claiming the most keys (a real/virtual keyboard
        # rather than a single power button).
        score = sum(bin(int(w, 16)).count("1") for w in keybits.split() if w)
        if best is None or score > best[0]:
            best = (score, handler)
    if best is None:
        raise SystemExit("No key-capable input device found; pass DEVICE explicitly.")
    return f"/dev/input/{best[1]}"


def send_key(key, device=None, press=True, release=True):
    """Inject an EV_KEY event by writing to the evdev node."""
    code = resolve_keycode(key)
    node = device or key_device()
    if not node.startswith("/dev/"):
        node = f"/dev/input/{node}"
    values = []
    if press:
        values.append(1)
    if release:
        values.append(0)
    emit = "".join(
        f"ev(fd,1,{code},{v});ev(fd,0,0,0);time.sleep(0.03)\n" for v in values
    )
    script = f'''import struct,os,time
def ev(fd,t,c,v):
 now=time.time();s=int(now);u=int((now-s)*1000000)
 os.write(fd,struct.pack("llHHi",s,u,t,c,v))
fd=os.open("{node}",os.O_WRONLY)
{emit}os.close(fd)'''
    r = ssh(f"""{PYTHON} -c '{script}'""")
    if r.returncode != 0:
        print(f"Key inject failed: {r.stderr.decode()}", file=sys.stderr)
        return
    what = "press+release" if (press and release) else ("press" if press else "release")
    print(f"Key {key} (code {code}) {what} -> {node}")


def record(seconds, output_path, fps=4, gif=False):
    """Capture framebuffer at `fps` Hz for `seconds`, encode with ffmpeg."""
    import tempfile, time, os
    from PIL import Image
    w, h = screen_size()
    frames = int(seconds * fps)
    tmpdir = tempfile.mkdtemp(prefix="kindle-rec-")
    print(f"Recording {seconds}s @ {fps} fps ({frames} frames) to {tmpdir}/")
    for i in range(frames):
        t0 = time.time()
        raw = ssh(f"cat {FB_DEV}").stdout
        if len(raw) >= w * h:
            Image.frombytes("L", (w, h), raw[:w * h]).save(f"{tmpdir}/f{i:04d}.png")
        elapsed = time.time() - t0
        slack = (1.0 / fps) - elapsed
        if slack > 0:
            time.sleep(slack)
    if gif:
        cmd = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-framerate", str(fps), "-i", f"{tmpdir}/f%04d.png",
            "-vf", f"scale={w//2}:{h//2}",
            output_path,
        ]
    else:
        cmd = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-framerate", str(fps), "-i", f"{tmpdir}/f%04d.png",
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
            output_path,
        ]
    subprocess.run(cmd, check=True)
    for f in os.listdir(tmpdir):
        os.unlink(f"{tmpdir}/{f}")
    os.rmdir(tmpdir)
    print(f"Wrote {output_path}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "screenshot":
        out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/kindle-screenshot.png"
        screenshot(out)
    elif cmd == "record" and len(sys.argv) >= 3:
        out = sys.argv[3] if len(sys.argv) > 3 else "/tmp/kindle-record.mp4"
        record(float(sys.argv[2]), out, gif=False)
    elif cmd == "record-gif" and len(sys.argv) >= 3:
        out = sys.argv[3] if len(sys.argv) > 3 else "/tmp/kindle-record.gif"
        record(float(sys.argv[2]), out, gif=True)
    elif cmd == "tap" and len(sys.argv) == 4:
        tap(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "tap-pct" and len(sys.argv) == 4:
        tap_pct(float(sys.argv[2]), float(sys.argv[3]))
    elif cmd == "swipe" and len(sys.argv) == 6:
        swipe(int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]))
    elif cmd == "scroll-up":
        w, h = screen_size()
        swipe(w // 2, h * 3 // 4, w // 2, h // 4)
    elif cmd == "scroll-down":
        w, h = screen_size()
        swipe(w // 2, h // 4, w // 2, h * 3 // 4)
    elif cmd in ("key", "key-down", "key-up") and len(sys.argv) >= 3:
        device = sys.argv[3] if len(sys.argv) > 3 else None
        send_key(sys.argv[2], device,
                 press=cmd != "key-up", release=cmd != "key-down")
    elif cmd == "keys":
        for name in sorted(KEYCODES, key=lambda n: KEYCODES[n]):
            print(f"{KEYCODES[name]:>4}  {name}")
    elif cmd == "screen-size":
        w, h = screen_size()
        print(f"{w}x{h}")
    elif cmd == "info":
        print(ssh("cat /proc/bus/input/devices").stdout.decode())
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
