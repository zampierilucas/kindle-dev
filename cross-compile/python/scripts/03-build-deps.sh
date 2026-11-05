#!/bin/bash
set -e

# Build cross-compiled native dependencies for Python packages
# These are required by Bumble and its dependencies

PREFIX="/output/python3.10-kindle"
DEPS_PREFIX="/output/deps"

echo "=== Building native dependencies ==="

mkdir -p "${DEPS_PREFIX}"
cd /build

# Set up cross-compilation environment
export CC=arm-kindle-linux-gnueabi-gcc
export CXX=arm-kindle-linux-gnueabi-g++
export AR=arm-kindle-linux-gnueabi-ar
export RANLIB=arm-kindle-linux-gnueabi-ranlib
export STRIP=arm-kindle-linux-gnueabi-strip
export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-Wl,-O1"

# ============================================
# 1. Build zlib (if not using system zlib)
# ============================================
build_zlib() {
    echo "=== Building zlib ==="
    ZLIB_VERSION="1.3.1"

    if [ ! -f "zlib-${ZLIB_VERSION}.tar.gz" ]; then
        wget "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz"
    fi
    tar xzf "zlib-${ZLIB_VERSION}.tar.gz"
    cd "zlib-${ZLIB_VERSION}"

    ./configure --prefix="${DEPS_PREFIX}"
    make -j$(nproc)
    make install
    cd ..
}

# ============================================
# 2. Build libffi
# ============================================
build_libffi() {
    echo "=== Building libffi ==="
    LIBFFI_VERSION="3.4.6"

    if [ ! -f "libffi-${LIBFFI_VERSION}.tar.gz" ]; then
        wget "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz"
    fi
    tar xzf "libffi-${LIBFFI_VERSION}.tar.gz"
    cd "libffi-${LIBFFI_VERSION}"

    ./configure \
        --prefix="${DEPS_PREFIX}" \
        --host=arm-kindle-linux-gnueabi \
        --build=x86_64-linux-gnu \
        --enable-shared \
        --disable-static

    make -j$(nproc)
    make install
    cd ..
}

# ============================================
# 3. Build libusb (for pyusb)
# ============================================
build_libusb() {
    echo "=== Building libusb ==="
    LIBUSB_VERSION="1.0.27"

    if [ ! -f "libusb-${LIBUSB_VERSION}.tar.bz2" ]; then
        wget "https://github.com/libusb/libusb/releases/download/v${LIBUSB_VERSION}/libusb-${LIBUSB_VERSION}.tar.bz2"
    fi
    tar xjf "libusb-${LIBUSB_VERSION}.tar.bz2"
    cd "libusb-${LIBUSB_VERSION}"

    ./configure \
        --prefix="${DEPS_PREFIX}" \
        --host=arm-kindle-linux-gnueabi \
        --build=x86_64-linux-gnu \
        --enable-shared \
        --disable-static \
        --disable-udev

    make -j$(nproc)
    make install
    cd ..
}

# Run builds
build_zlib
build_libffi
build_libusb

echo "=== Dependencies installed to ${DEPS_PREFIX} ==="
ls -la "${DEPS_PREFIX}/lib/"
