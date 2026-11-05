use std::io::{self, Read, Write};
use std::os::unix::net::UnixStream;

pub struct X11 {
    sock: UnixStream,
    root: u32,
    pub width: u16,
    pub height: u16,
}

fn u16_at(b: &[u8], i: usize) -> u16 {
    u16::from_le_bytes([b[i], b[i + 1]])
}

fn err(msg: String) -> io::Error {
    io::Error::other(msg)
}

impl X11 {
    pub fn connect() -> io::Result<Self> {
        let mut sock = UnixStream::connect("/tmp/.X11-unix/X0")?;
        sock.write_all(&[0x6c, 0, 11, 0, 0, 0, 0, 0, 0, 0, 0, 0])?;
        let mut header = [0u8; 8];
        sock.read_exact(&mut header)?;
        if header[0] != 1 {
            return Err(err(format!("X11 connect refused, status {}", header[0])));
        }
        let mut setup = vec![0u8; u16_at(&header, 6) as usize * 4];
        sock.read_exact(&mut setup)?;

        let vendor_len = u16_at(&setup, 16) as usize;
        let screen = 32 + vendor_len.div_ceil(4) * 4 + setup[21] as usize * 8;
        Ok(X11 {
            sock,
            root: u32::from_le_bytes(setup[screen..screen + 4].try_into().unwrap()),
            width: u16_at(&setup, screen + 20),
            height: u16_at(&setup, screen + 22),
        })
    }

    fn xtest_opcode(&mut self) -> io::Result<u8> {
        let name = b"XTEST";
        let pad = (4 - name.len() % 4) % 4;
        let mut req = vec![98, 0];
        req.extend_from_slice(&(((8 + name.len() + pad) / 4) as u16).to_le_bytes());
        req.extend_from_slice(&(name.len() as u16).to_le_bytes());
        req.extend_from_slice(&[0, 0]);
        req.extend_from_slice(name);
        req.resize(req.len() + pad, 0);
        self.sock.write_all(&req)?;
        let mut reply = [0u8; 32];
        self.sock.read_exact(&mut reply)?;
        if reply[8] == 0 {
            return Err(err("X server has no XTEST extension".into()));
        }
        Ok(reply[9])
    }

    fn fake_input(&mut self, op: u8, kind: u8, detail: u8, x: i16, y: i16, delay: u32) -> io::Result<()> {
        let mut req = [0u8; 36];
        req[..4].copy_from_slice(&[op, 2, 9, 0]);
        req[4] = kind;
        req[5] = detail;
        req[8..12].copy_from_slice(&delay.to_le_bytes());
        req[12..16].copy_from_slice(&self.root.to_le_bytes());
        req[24..26].copy_from_slice(&x.to_le_bytes());
        req[26..28].copy_from_slice(&y.to_le_bytes());
        self.sock.write_all(&req)
    }

    fn wait_until_processed(&mut self) -> io::Result<()> {
        self.sock.write_all(&[43, 0, 1, 0])?;
        self.sock.read_exact(&mut [0u8; 32])
    }

    pub fn tap(&mut self, x: i16, y: i16) -> io::Result<()> {
        let op = self.xtest_opcode()?;
        self.fake_input(op, 6, 0, x, y, 0)?;
        self.fake_input(op, 4, 1, x, y, 0)?;
        self.fake_input(op, 5, 1, x, y, 50)?;
        self.wait_until_processed()
    }
}
