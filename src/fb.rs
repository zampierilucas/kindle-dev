use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom, Write};
use std::os::fd::AsRawFd;

const FBIOGET_VSCREENINFO: libc::c_ulong = 0x4600;
const FBIOGET_FSCREENINFO: libc::c_ulong = 0x4602;

#[repr(C)]
struct FixInfo {
    id: [u8; 16],
    smem_start: libc::c_ulong,
    smem_len: u32,
    kind: u32,
    type_aux: u32,
    visual: u32,
    xpanstep: u16,
    ypanstep: u16,
    ywrapstep: u16,
    line_length: u32,
    mmio_start: libc::c_ulong,
    mmio_len: u32,
    accel: u32,
    capabilities: u16,
    reserved: [u16; 2],
}

pub struct Framebuffer {
    file: File,
    pub width: usize,
    pub height: usize,
    bpp: usize,
    stride: usize,
    yoffset: usize,
    shifts: [u32; 3],
}

fn ioctl<T>(file: &File, req: libc::c_ulong, out: &mut T) -> io::Result<()> {
    if unsafe { libc::ioctl(file.as_raw_fd(), req as _, out as *mut T) } < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

impl Framebuffer {
    pub fn open() -> io::Result<Self> {
        let file = File::open("/dev/fb0")?;
        let mut var = [0u32; 40];
        ioctl(&file, FBIOGET_VSCREENINFO, &mut var)?;
        let mut fix: FixInfo = unsafe { std::mem::zeroed() };
        ioctl(&file, FBIOGET_FSCREENINFO, &mut fix)?;
        Ok(Framebuffer {
            file,
            width: var[0] as usize,
            height: var[1] as usize,
            yoffset: var[5] as usize,
            bpp: var[6] as usize,
            stride: fix.line_length as usize,
            shifts: [var[8], var[11], var[14]],
        })
    }

    pub fn write_png(&mut self, out: impl Write) -> io::Result<()> {
        let mut raw = vec![0u8; self.stride * self.height];
        self.file.seek(SeekFrom::Start((self.yoffset * self.stride) as u64))?;
        self.file.read_exact(&mut raw)?;

        let (color, pixels) = match self.bpp {
            8 => (
                png::ColorType::Grayscale,
                raw.chunks(self.stride).flat_map(|row| &row[..self.width]).copied().collect(),
            ),
            32 => (
                png::ColorType::Rgb,
                raw.chunks(self.stride)
                    .flat_map(|row| row[..self.width * 4].chunks(4))
                    .flat_map(|px| {
                        let v = u32::from_le_bytes(px.try_into().unwrap());
                        self.shifts.map(|s| (v >> s) as u8)
                    })
                    .collect::<Vec<u8>>(),
            ),
            n => {
                return Err(io::Error::new(
                    io::ErrorKind::Unsupported,
                    format!("{n} bits per pixel framebuffer is not supported"),
                ))
            }
        };

        let mut enc = png::Encoder::new(out, self.width as u32, self.height as u32);
        enc.set_color(color);
        enc.set_compression(png::Compression::Fast);
        let mut w = enc.write_header().map_err(io::Error::other)?;
        w.write_image_data(&pixels).map_err(io::Error::other)?;
        w.finish().map_err(io::Error::other)
    }
}
