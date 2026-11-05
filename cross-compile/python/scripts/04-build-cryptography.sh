#!/bin/bash
set -e

# Build cryptography Python package with Rust for ARM glibc
# This is one of the most complex dependencies

PREFIX="/output/python3.10-kindle"
OPENSSL_PREFIX="/output/openssl"

echo "=== Building cryptography package ==="

cd /build

# Set up cross-compilation environment for Rust
export CARGO_BUILD_TARGET=armv7-unknown-linux-gnueabi
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-kindle-linux-gnueabi-gcc

# Add the Rust target
rustup target add armv7-unknown-linux-gnueabi 2>/dev/null || true

# Set up Python cross-compilation environment
export CC=arm-kindle-linux-gnueabi-gcc
export CXX=arm-kindle-linux-gnueabi-g++
export AR=arm-kindle-linux-gnueabi-ar
export RANLIB=arm-kindle-linux-gnueabi-ranlib
export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC"
export LDFLAGS="-L${OPENSSL_PREFIX}/lib"

# OpenSSL environment for cryptography
export OPENSSL_DIR="${OPENSSL_PREFIX}"
export OPENSSL_LIB_DIR="${OPENSSL_PREFIX}/lib"
export OPENSSL_INCLUDE_DIR="${OPENSSL_PREFIX}/include"
export OPENSSL_STATIC=1

# Build cryptography
# We'll use crossenv or build manually
CRYPTOGRAPHY_VERSION="44.0.3"

pip3 download --no-binary :all: "cryptography==${CRYPTOGRAPHY_VERSION}" -d /build/wheels/
cd /build/wheels
tar xzf cryptography-${CRYPTOGRAPHY_VERSION}.tar.gz
cd cryptography-${CRYPTOGRAPHY_VERSION}

# Build the wheel
# This requires special handling for cross-compilation
python3 -m pip wheel . \
    --no-deps \
    --wheel-dir=/output/wheels/ \
    -v

echo "=== cryptography built ==="
ls -la /output/wheels/
