#!/bin/bash
set -e

# Build cffi Python package for ARM glibc
# cffi requires libffi

PREFIX="/output/python3.10-kindle"
DEPS_PREFIX="/output/deps"
LIBFFI_PREFIX="${DEPS_PREFIX}"

echo "=== Building cffi package ==="

cd /build

# First, ensure we have libffi built
if [ ! -f "${LIBFFI_PREFIX}/lib/libffi.so" ]; then
    echo "Building libffi first..."
    LIBFFI_VERSION="3.4.6"

    if [ ! -f "libffi-${LIBFFI_VERSION}.tar.gz" ]; then
        wget "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz"
    fi
    rm -rf "libffi-${LIBFFI_VERSION}"
    tar xzf "libffi-${LIBFFI_VERSION}.tar.gz"
    cd "libffi-${LIBFFI_VERSION}"

    # Unset host CC for configure
    unset CC CXX AR RANLIB

    ./configure \
        --prefix="${LIBFFI_PREFIX}" \
        --host=arm-kindle-linux-gnueabi \
        --build=x86_64-linux-gnu \
        --enable-shared \
        --disable-static

    # Set CC for make
    export CC=arm-kindle-linux-gnueabi-gcc
    export AR=arm-kindle-linux-gnueabi-ar
    export RANLIB=arm-kindle-linux-gnueabi-ranlib

    make -j$(nproc)
    make install
    cd /build
fi

echo "=== libffi installed ==="
ls -la "${LIBFFI_PREFIX}/lib/"*ffi* 2>/dev/null || true

# Set up cross-compilation environment for cffi
export CC=arm-kindle-linux-gnueabi-gcc
export CXX=arm-kindle-linux-gnueabi-g++
export AR=arm-kindle-linux-gnueabi-ar
export RANLIB=arm-kindle-linux-gnueabi-ranlib
export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC -I${LIBFFI_PREFIX}/include"
export LDFLAGS="-L${LIBFFI_PREFIX}/lib -Wl,-rpath,'\$\$ORIGIN/../lib'"
export PKG_CONFIG_PATH="${LIBFFI_PREFIX}/lib/pkgconfig"

# Download cffi source
CFFI_VERSION="1.17.1"
mkdir -p /build/cffi_build
cd /build/cffi_build

pip3 download --no-binary :all: "cffi==${CFFI_VERSION}" -d .
tar xzf cffi-${CFFI_VERSION}.tar.gz
cd cffi-${CFFI_VERSION}

# We need to use crossenv or build manually
# For cross-compilation, we'll use the host Python to run setup.py
# but with cross-compile flags

# Set FFI_* environment variables for cffi's setup.py
export FFI_INC="${LIBFFI_PREFIX}/include"
export FFI_LIB="${LIBFFI_PREFIX}/lib"

# Build using host Python but with cross-compile CC
echo "Building cffi..."
python3 setup.py build_ext \
    --include-dirs="${LIBFFI_PREFIX}/include" \
    --library-dirs="${LIBFFI_PREFIX}/lib" \
    --rpath='$ORIGIN/../lib'

# Install to the target prefix
python3 setup.py install \
    --prefix="${PREFIX}" \
    --install-lib="${PREFIX}/lib/python3.10/site-packages"

echo "=== cffi built ==="
ls -la "${PREFIX}/lib/python3.10/site-packages/"*cffi* 2>/dev/null || true

# Copy libffi to the Python installation
cp -a "${LIBFFI_PREFIX}/lib/libffi.so"* "${PREFIX}/lib/" 2>/dev/null || true

echo "=== Done ==="
