#!/usr/bin/env python3
"""Inject X11 tap via XTEST extension using raw X11 protocol.

Pure Python — no ctypes, no Xlib bindings needed.
Reads screen dimensions from the X11 connection setup.

Usage:
    xtap.py X Y           Tap at absolute pixel coordinates
    xtap.py info          Show screen dimensions
"""
import socket
import struct
import sys


class X11Connection:
    def __init__(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect("/tmp/.X11-unix/X0")
        self.seq = 0
        self.root = 0
        self.width = 0
        self.height = 0
        self._handshake()

    def _recv(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("X11 closed")
            buf += chunk
        return buf

    def _handshake(self):
        self.sock.send(struct.pack("<BxHHHH2x", 0x6C, 11, 0, 0, 0))
        header = self._recv(8)
        if header[0] != 1:
            raise RuntimeError(f"X11 connect failed: status={header[0]}")
        extra = struct.unpack_from("<H", header, 6)[0]
        setup = self._recv(extra * 4)

        vendor_len = struct.unpack_from("<H", setup, 16)[0]
        vendor_pad = (4 - (vendor_len % 4)) % 4
        num_pf = setup[21]
        screen_off = 32 + vendor_len + vendor_pad + num_pf * 8

        self.root = struct.unpack_from("<I", setup, screen_off)[0]
        # Screen struct: root(4), colormap(4), white(4), black(4),
        #   input_masks(4), width_px(2), height_px(2), width_mm(2), height_mm(2), ...
        self.width = struct.unpack_from("<H", setup, screen_off + 20)[0]
        self.height = struct.unpack_from("<H", setup, screen_off + 22)[0]

    def send_request(self, data):
        self.sock.send(data)
        self.seq += 1

    def query_extension(self, name):
        name_bytes = name.encode("ascii")
        pad = (4 - (len(name_bytes) % 4)) % 4
        req_len = (8 + len(name_bytes) + pad) // 4
        req = struct.pack("<BBH", 98, 0, req_len)
        req += struct.pack("<H2x", len(name_bytes))
        req += name_bytes + b"\x00" * pad
        self.send_request(req)
        reply = self._recv(32)
        if not reply[8]:
            raise RuntimeError(f"Extension '{name}' not present")
        return reply[9]

    def xtest_fake_input(self, opcode, event_type, detail, root_x, root_y, delay=0):
        req = bytearray(36)
        struct.pack_into("<BBH", req, 0, opcode, 2, 9)
        req[4] = event_type
        req[5] = detail
        struct.pack_into("<I", req, 8, delay)
        struct.pack_into("<I", req, 12, self.root)
        struct.pack_into("<hh", req, 24, root_x, root_y)
        self.send_request(bytes(req))

    def flush(self):
        self.send_request(struct.pack("<BBH", 43, 0, 1))
        self._recv(32)

    def close(self):
        self.sock.close()


def tap(x, y):
    conn = X11Connection()

    if x < 0 or x > conn.width or y < 0 or y > conn.height:
        print(f"WARNING: ({x},{y}) outside screen ({conn.width}x{conn.height})",
              file=sys.stderr)

    xtest = conn.query_extension("XTEST")
    conn.xtest_fake_input(xtest, 6, 0, x, y)       # MotionNotify
    conn.xtest_fake_input(xtest, 4, 1, x, y)        # ButtonPress
    conn.xtest_fake_input(xtest, 5, 1, x, y, 50)    # ButtonRelease
    conn.flush()
    conn.close()


def info():
    conn = X11Connection()
    print(f"{conn.width}x{conn.height}")
    conn.close()


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "info":
        info()
    elif len(sys.argv) == 3:
        tap(int(sys.argv[1]), int(sys.argv[2]))
    else:
        print("Usage: xtap.py X Y | xtap.py info")
        sys.exit(1)
