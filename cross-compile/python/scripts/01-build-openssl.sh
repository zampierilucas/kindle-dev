#!/bin/bash
set -e

# Build OpenSSL for ARM glibc (Kindle)
# Required for Python's ssl module and cryptography package

OPENSSL_VERSION="3.0.15"
PREFIX="/output/openssl"

echo "=== Building OpenSSL ${OPENSSL_VERSION} ==="

cd /build

# Download OpenSSL
if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
    wget "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"
fi
tar xzf "openssl-${OPENSSL_VERSION}.tar.gz"
cd "openssl-${OPENSSL_VERSION}"

# Configure for ARM Linux with glibc
# Using linux-armv4 as the base target and customizing
# Unset the CC/CXX env vars that conflict with OpenSSL's configure
unset CC CXX AR RANLIB

./Configure linux-armv4 \
    --prefix="${PREFIX}" \
    --openssldir="${PREFIX}/ssl" \
    --cross-compile-prefix=arm-kindle-linux-gnueabi- \
    no-async \
    no-zlib \
    shared \
    "-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -fPIC"

make -j$(nproc)
make install_sw install_ssldirs

echo "=== OpenSSL installed to ${PREFIX} ==="
ls -la "${PREFIX}/lib/"
