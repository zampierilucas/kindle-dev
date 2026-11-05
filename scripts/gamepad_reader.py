#!/usr/bin/env python3
"""
Simple gamepad/input event reader for Kindle Alpine Linux
Reads raw input events without external dependencies.

Usage: python3 gamepad_reader.py /dev/input/event0
"""

import sys
import os
import struct
import fcntl
import glob

# Input event types
EV_SYN = 0x00
EV_KEY = 0x01
EV_REL = 0x02
EV_ABS = 0x03
EV_MSC = 0x04

TYPE_NAMES = {
    EV_SYN: "SYN",
    EV_KEY: "KEY",
    EV_REL: "REL",
    EV_ABS: "ABS",
    EV_MSC: "MSC",
}

# Common gamepad buttons
KEY_NAMES = {
    304: "BTN_A/SOUTH",
    305: "BTN_B/EAST",
    306: "BTN_C",
    307: "BTN_X/NORTH",
    308: "BTN_Y/WEST",
    309: "BTN_Z",
    310: "BTN_TL (L1)",
    311: "BTN_TR (R1)",
    312: "BTN_TL2 (L2)",
    313: "BTN_TR2 (R2)",
    314: "BTN_SELECT",
    315: "BTN_START",
    316: "BTN_MODE",
    317: "BTN_THUMBL (L3)",
    318: "BTN_THUMBR (R3)",
    544: "DPAD_UP",
    545: "DPAD_DOWN",
    546: "DPAD_LEFT",
    547: "DPAD_RIGHT",
}

# Common axes
ABS_NAMES = {
    0: "LEFT_X",
    1: "LEFT_Y",
    2: "L2_TRIGGER",
    3: "RIGHT_X",
    4: "RIGHT_Y",
    5: "R2_TRIGGER",
    16: "DPAD_X",
    17: "DPAD_Y",
}

# ioctl constants
EVIOCGNAME = lambda length: 0x80000000 | (length << 16) | (ord('E') << 8) | 0x06
EVIOCGID = 0x80084502

def get_device_name(fd):
    """Get device name via ioctl"""
    try:
        buf = bytearray(256)
        fcntl.ioctl(fd, EVIOCGNAME(256), buf)
        return buf.split(b'\x00')[0].decode('utf-8', errors='replace')
    except:
        return "Unknown"

def list_devices():
    """List available input devices"""
    print("Available input devices:")
    for path in sorted(glob.glob('/dev/input/event*')):
        try:
            fd = os.open(path, os.O_RDONLY)
            name = get_device_name(fd)
            os.close(fd)
            print(f"  {path}: {name}")
        except PermissionError:
            print(f"  {path}: (permission denied)")
        except Exception as e:
            print(f"  {path}: (error: {e})")
    print()

def read_events(device_path):
    """Read and print input events"""
    try:
        fd = os.open(device_path, os.O_RDONLY)
    except PermissionError:
        print(f"Permission denied: {device_path}")
        print("Try running as root or add user to 'input' group")
        sys.exit(1)
    except FileNotFoundError:
        print(f"Device not found: {device_path}")
        list_devices()
        sys.exit(1)

    print(f"Reading from: {device_path}")
    print(f"Device name: {get_device_name(fd)}")
    print("-" * 50)
    print("Press Ctrl+C to exit\n")

    # Input event format: struct input_event
    # On 32-bit ARM: sec(4) + usec(4) + type(2) + code(2) + value(4) = 16 bytes
    EVENT_FORMAT = 'IIHHi'  # 32-bit timestamps
    EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

    try:
        while True:
            data = os.read(fd, EVENT_SIZE)
            if len(data) < EVENT_SIZE:
                break

            sec, usec, ev_type, code, value = struct.unpack(EVENT_FORMAT, data)

            # Skip sync events
            if ev_type == EV_SYN:
                continue

            type_name = TYPE_NAMES.get(ev_type, f"T{ev_type}")

            if ev_type == EV_KEY:
                key_name = KEY_NAMES.get(code)
                if key_name:
                    state = "PRESSED" if value else "RELEASED"
                    print(f"[{type_name}] {key_name} = {value} ({state})")
                else:
                    print(f"[{type_name}] code={code} value={value}")

            elif ev_type == EV_ABS:
                abs_name = ABS_NAMES.get(code)
                if abs_name:
                    print(f"[{type_name}] {abs_name} = {value}")
                else:
                    print(f"[{type_name}] code={code} value={value}")
            else:
                print(f"[{type_name}] code={code} value={value}")

    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        os.close(fd)

def main():
    if len(sys.argv) < 2:
        print("Gamepad Input Reader for Kindle\n")
        list_devices()
        print(f"Usage: {sys.argv[0]} /dev/input/eventX")
        print(f"       {sys.argv[0]} -l  (list devices only)")
        sys.exit(1)

    if sys.argv[1] == '-l':
        list_devices()
        sys.exit(0)

    read_events(sys.argv[1])

if __name__ == '__main__':
    main()
