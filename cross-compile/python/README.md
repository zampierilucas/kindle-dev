# Kindle Python 3.10+ Cross-Compilation

Cross-compile Python 3.10+ with musl libc for Amazon Kindle (ARMv7 hard-float).

## Overview

The Kindle (MT8512/Cortex-A53) uses:
- ARMv7-A architecture with NEON VFPv4
- Hard-float ABI
- glibc 2.20 (system) but the existing Python 3.8 uses musl libc

We build a standalone Python 3.10+ using musl libc, which runs independently of the system's glibc.

## Quick Start

```bash
./build.sh
```

This will:
1. Build a Docker image with the musl cross-compiler
2. Cross-compile OpenSSL 3.0
3. Cross-compile Python 3.10
4. Build native dependencies (zlib, libffi, libusb)

Output goes to `./output/python3.10-kindle/`

## Manual Steps

### Build the Docker image

```bash
docker build -t kindle-cross-compile .
```

### Run interactive shell

```bash
docker run --rm -it \
    -v $(pwd)/output:/output \
    -v $(pwd)/scripts:/scripts \
    kindle-cross-compile \
    bash
```

### Build steps (inside container)

```bash
/scripts/01-build-openssl.sh
/scripts/02-build-python.sh
/scripts/03-build-deps.sh
```

## Deployment to Kindle

```bash
rsync -avz output/python3.10-kindle/ kindle:/mnt/us/python3.10-kindle/
```

Then on Kindle:
```bash
/mnt/us/python3.10-kindle/python3-wrapper.sh --version
```

## Native Dependencies for Bumble

Bumble requires these native packages:
- `cryptography` - Needs Rust cross-compilation
- `aiohttp` - C extensions
- `grpcio` - Optional, complex C++ build

### cryptography

This is the hardest dependency. Options:
1. Cross-compile with Rust (complex)
2. Use `cryptography<40` which has pure-Python fallback for some operations
3. Build on Kindle itself (slow but works)

### aiohttp

Can be built with:
```bash
pip wheel aiohttp --no-deps
```
Using crossenv or similar.

## Target Architecture

```
CPU: MediaTek MT8512 (Cortex-A53 cores, ARMv7 mode)
Compiler flags: -march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -mtune=cortex-a53
Linker: /lib/ld-musl-armhf.so.1
```

## Directory Structure

```
cross-compile/
├── Dockerfile          # Build environment
├── build.sh            # Main build script
├── scripts/
│   ├── 01-build-openssl.sh
│   ├── 02-build-python.sh
│   ├── 03-build-deps.sh
│   ├── 04-build-cryptography.sh
│   └── 05-install-bumble.sh
├── output/             # Build outputs
│   ├── openssl/
│   ├── python3.10-kindle/
│   ├── deps/
│   └── wheels/
└── sysroot/            # Kindle libraries (for reference)
```
