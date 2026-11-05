# kindle-ai-dev-tools

Scripts and AI agent skills I use for Kindle hacking, plus a list of the tools that get you from a stock Kindle to writing code for it.

Everything here assumes a jailbroken Kindle you can SSH into. If you are not there yet, start with the jailbreak guides below.

## What's in here

| Path | What it does |
|---|---|
| `skills/kindle-remote/` | Claude Code skill that lets an agent see and drive the Kindle screen over SSH, so it can check its own UI changes |
| `scripts/kindle-remote.py` | Host side of the above. Screenshot, record mp4/gif, tap, swipe, scroll and inject keys over SSH |
| `scripts/xtap.py` | Runs on the Kindle. Pure Python X11 XTEST tap injection, no Xlib needed |
| `scripts/gamepad_reader.py` | Dumps raw evdev events from any input device, decoded |
| `scripts/gamepad_reader.c` | Same thing in C, for when there is no Python on the device |
| `scripts/gamepad_hexdump.sh` | Same thing with busybox `hexdump`, nothing to install |
| `scripts/download_dictionaries.sh` | Downloads English StarDict dictionaries for KOReader |
| `cross-compile/python/` | Docker build for a standalone musl Python 3.10 (with OpenSSL, cffi, cryptography, bumble) for ARMv7 Kindles |
| `cross-compile/kernel/` | Builds `uhid.ko` and `uinput.ko` against Amazon's GPL kernel source for a given Kindle model |

### Using the skill

Copy it where Claude Code looks for skills and point it at your Kindle.

```sh
cp -r skills/kindle-remote ~/.claude/skills/
scp scripts/xtap.py kindle:/mnt/us/xtap.py
export KINDLE_HOST=kindle                 # SSH host or alias
export KINDLE_XTAP=/mnt/us/xtap.py
export KINDLE_PYTHON=python3              # whatever Python you have on the device
```

Host needs Pillow, and ffmpeg for recording. Then ask the agent to take a screenshot of the Kindle and it will take it from there.

XTEST taps only reach the native Kindle UI. KOReader reads evdev directly, so use `swipe` or `key` against it instead of `tap`.

## Tools

### Getting in

| Tool | What it's for |
|---|---|
| [kindlemodding.org](https://kindlemodding.org/) | Jailbreak guides per firmware, and what to install after |
| [KindleModding/Hotfix](https://github.com/KindleModding/Hotfix) | Keeps the jailbreak alive across firmware updates |
| [KindleModding/KPM](https://github.com/KindleModding/KPM) | Kindle Package Manager ([docs](https://kindlemodding.org/kindle-dev/kpm/)) |
| [KindleTweaks/KindleForge](https://github.com/KindleTweaks/KindleForge) | GUI package manager on the Kindle |
| [notmarek/kindle-usbnetlite](https://github.com/notmarek/kindle-usbnetlite) | Minimal usbnet, gets you an SSH shell on the Kindle |

### Apps

| Tool | What it's for |
|---|---|
| [koreader/koreader](https://github.com/koreader/koreader) | The reader most people end up on, and a good Lua codebase to hack on |
| [zampierilucas/kindle-hid-passthrough](https://github.com/zampierilucas/kindle-hid-passthrough) | Bluetooth keyboards, page turners and gamepads on Kindle |
| [zampierilucas/kindle-button-mapper-rs](https://github.com/zampierilucas/kindle-button-mapper-rs) | Map controller and remote buttons to Kindle actions |

### Development

| Tool | What it's for |
|---|---|
| [katadelos/eink-emulator](https://github.com/katadelos/eink-emulator) | Run Kindle firmware in QEMU, so you can break things without a device |
| [NiLuJe/KindleTool](https://github.com/NiLuJe/KindleTool) | Create and extract Kindle update packages |
| [Amazon GPL source](https://www.amazon.com/gp/help/customer/display.html?nodeId=200203720) | Kernel and GPL sources per Kindle firmware, what `cross-compile/kernel` builds against |
| [katadelos/linux-3.0.35-lab126](https://github.com/katadelos/linux-3.0.35-lab126) | Kindle kernel tree as git, easier to read than the tarballs |
| [ftvdb.com Kindle firmware](https://ftvdb.com/kindle/firmware/) | Archive of Kindle firmware images |
| [google/bumble](https://github.com/google/bumble) | Python Bluetooth stack, what kindle-hid-passthrough is built on |

PRs adding tools or skills are welcome.

## License

GPL-3.0
