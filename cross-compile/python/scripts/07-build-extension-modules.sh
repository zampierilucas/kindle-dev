#!/bin/bash
set -e

# Build Python extension modules separately
# This script compiles critical extension modules for ARM

PREFIX="/output/python3.10-kindle"
OPENSSL_PREFIX="/output/openssl"
PYTHON_VERSION="3.10.16"

echo "=== Building Extension Modules for Python ${PYTHON_VERSION} ==="

cd /build

# Download Python if needed
if [ ! -f "Python-${PYTHON_VERSION}.tar.xz" ]; then
    wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
fi

# Extract fresh
rm -rf "Python-${PYTHON_VERSION}"
tar xJf "Python-${PYTHON_VERSION}.tar.xz"
cd "Python-${PYTHON_VERSION}"

# Create the output directory
mkdir -p "${PREFIX}/lib/python3.10/lib-dynload"

# First, we need to configure Python to generate pyconfig.h
echo "=== Configuring Python for cross-compilation ==="

# Unset for native build first
unset CC CXX AR RANLIB STRIP READELF CFLAGS CXXFLAGS LDFLAGS

# Build native Python for Parser/pgen
mkdir -p build-native
cd build-native
../configure --disable-shared
make -j$(nproc) python Parser/pgen 2>/dev/null || make -j$(nproc) python
PYTHON_FOR_BUILD=$(pwd)/python
cd ..

# Now configure for cross-compilation
mkdir -p build-arm
cd build-arm

# Set up cross-compilation environment
export CC=arm-kindle-linux-gnueabi-gcc
export CXX=arm-kindle-linux-gnueabi-g++
export AR=arm-kindle-linux-gnueabi-ar
export RANLIB=arm-kindle-linux-gnueabi-ranlib
export STRIP=arm-kindle-linux-gnueabi-strip
export READELF=arm-kindle-linux-gnueabi-readelf

# ARM-specific flags - keep LDFLAGS clean for configure (no library paths or rpath)
export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS=""

ln -sf "${PYTHON_FOR_BUILD}" /usr/local/bin/python3.10

CONFIG_SITE=/dev/null ../configure \
    --prefix="${PREFIX}" \
    --host=arm-kindle-linux-gnueabi \
    --build=x86_64-linux-gnu \
    --enable-shared \
    --with-openssl="${OPENSSL_PREFIX}" \
    --disable-ipv6 \
    --without-ensurepip \
    ac_cv_file__dev_ptmx=yes \
    ac_cv_file__dev_ptc=no \
    ac_cv_buggy_getaddrinfo=no \
    ac_cv_have_long_long_format=yes \
    ac_cv_working_tzset=yes \
    PYTHON_FOR_BUILD="${PYTHON_FOR_BUILD}"

echo "=== Configuration complete, pyconfig.h generated ==="

# Now build extension modules as shared libraries
echo "=== Building extension modules ==="

# Clean old hard-float modules from lib-dynload
echo "Cleaning old hard-float extension modules..."
rm -f "${PREFIX}/lib/python3.10/lib-dynload/"*.cpython-310-arm-linux-gnueabihf.so

# Set include paths with the configured build directory
INCLUDE_FLAGS="-I../Include -I. -I../Include/internal -I${OPENSSL_PREFIX}/include"
MODULE_LDFLAGS="-L${OPENSSL_PREFIX}/lib -L${PREFIX}/lib"

# Build _socket module
echo "=== Building _socket module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _socket.cpython-310-arm-linux-gnueabi.so \
    ../Modules/socketmodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _socket module failed"

if [ -f _socket.cpython-310-arm-linux-gnueabi.so ]; then
    cp _socket.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_socket module built successfully"
fi

# Build select module
echo "=== Building select module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o select.cpython-310-arm-linux-gnueabi.so \
    ../Modules/selectmodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: select module failed"

if [ -f select.cpython-310-arm-linux-gnueabi.so ]; then
    cp select.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "select module built successfully"
fi

# Build _asyncio module
echo "=== Building _asyncio module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _asyncio.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_asynciomodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _asyncio module failed"

if [ -f _asyncio.cpython-310-arm-linux-gnueabi.so ]; then
    cp _asyncio.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_asyncio module built successfully"
fi

# Build _struct module
echo "=== Building _struct module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _struct.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_struct.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _struct module failed"

if [ -f _struct.cpython-310-arm-linux-gnueabi.so ]; then
    cp _struct.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_struct module built successfully"
fi

# Build binascii module
echo "=== Building binascii module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o binascii.cpython-310-arm-linux-gnueabi.so \
    ../Modules/binascii.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: binascii module failed"

if [ -f binascii.cpython-310-arm-linux-gnueabi.so ]; then
    cp binascii.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "binascii module built successfully"
fi

# Build _posixsubprocess module
echo "=== Building _posixsubprocess module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _posixsubprocess.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_posixsubprocess.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _posixsubprocess module failed"

if [ -f _posixsubprocess.cpython-310-arm-linux-gnueabi.so ]; then
    cp _posixsubprocess.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_posixsubprocess module built successfully"
fi

# Build fcntl module
echo "=== Building fcntl module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o fcntl.cpython-310-arm-linux-gnueabi.so \
    ../Modules/fcntlmodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: fcntl module failed"

if [ -f fcntl.cpython-310-arm-linux-gnueabi.so ]; then
    cp fcntl.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "fcntl module built successfully"
fi

# Build math module
echo "=== Building math module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o math.cpython-310-arm-linux-gnueabi.so \
    ../Modules/mathmodule.c ../Modules/_math.c \
    -lm $MODULE_LDFLAGS 2>&1 || echo "WARNING: math module failed"

if [ -f math.cpython-310-arm-linux-gnueabi.so ]; then
    cp math.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "math module built successfully"
fi

# Build _random module
echo "=== Building _random module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _random.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_randommodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _random module failed"

if [ -f _random.cpython-310-arm-linux-gnueabi.so ]; then
    cp _random.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_random module built successfully"
fi

# Build _datetime module
echo "=== Building _datetime module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _datetime.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_datetimemodule.c \
    -lm $MODULE_LDFLAGS 2>&1 || echo "WARNING: _datetime module failed"

if [ -f _datetime.cpython-310-arm-linux-gnueabi.so ]; then
    cp _datetime.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_datetime module built successfully"
fi

# Build array module
echo "=== Building array module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o array.cpython-310-arm-linux-gnueabi.so \
    ../Modules/arraymodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: array module failed"

if [ -f array.cpython-310-arm-linux-gnueabi.so ]; then
    cp array.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "array module built successfully"
fi

# Build _bisect module
echo "=== Building _bisect module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _bisect.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_bisectmodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _bisect module failed"

if [ -f _bisect.cpython-310-arm-linux-gnueabi.so ]; then
    cp _bisect.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_bisect module built successfully"
fi

# Build _heapq module
echo "=== Building _heapq module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _heapq.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_heapqmodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _heapq module failed"

if [ -f _heapq.cpython-310-arm-linux-gnueabi.so ]; then
    cp _heapq.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_heapq module built successfully"
fi

# Build _json module
echo "=== Building _json module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _json.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_json.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _json module failed"

if [ -f _json.cpython-310-arm-linux-gnueabi.so ]; then
    cp _json.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_json module built successfully"
fi

# Build _pickle module
echo "=== Building _pickle module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _pickle.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_pickle.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _pickle module failed"

if [ -f _pickle.cpython-310-arm-linux-gnueabi.so ]; then
    cp _pickle.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_pickle module built successfully"
fi

# Build _contextvars module
echo "=== Building _contextvars module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _contextvars.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_contextvarsmodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _contextvars module failed"

if [ -f _contextvars.cpython-310-arm-linux-gnueabi.so ]; then
    cp _contextvars.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_contextvars module built successfully"
fi

# Build _queue module
echo "=== Building _queue module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _queue.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_queuemodule.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _queue module failed"

if [ -f _queue.cpython-310-arm-linux-gnueabi.so ]; then
    cp _queue.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_queue module built successfully"
fi

# Build _hashlib module (uses OpenSSL)
echo "=== Building _hashlib module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _hashlib.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_hashopenssl.c \
    -I${OPENSSL_PREFIX}/include \
    -L${OPENSSL_PREFIX}/lib -lssl -lcrypto \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _hashlib module failed"

if [ -f _hashlib.cpython-310-arm-linux-gnueabi.so ]; then
    cp _hashlib.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_hashlib module built successfully"
fi

# Build _md5 module
echo "=== Building _md5 module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _md5.cpython-310-arm-linux-gnueabi.so \
    ../Modules/md5module.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _md5 module failed"

if [ -f _md5.cpython-310-arm-linux-gnueabi.so ]; then
    cp _md5.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_md5 module built successfully"
fi

# Build _sha1 module
echo "=== Building _sha1 module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _sha1.cpython-310-arm-linux-gnueabi.so \
    ../Modules/sha1module.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _sha1 module failed"

if [ -f _sha1.cpython-310-arm-linux-gnueabi.so ]; then
    cp _sha1.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_sha1 module built successfully"
fi

# Build _sha256 module
echo "=== Building _sha256 module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _sha256.cpython-310-arm-linux-gnueabi.so \
    ../Modules/sha256module.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _sha256 module failed"

if [ -f _sha256.cpython-310-arm-linux-gnueabi.so ]; then
    cp _sha256.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_sha256 module built successfully"
fi

# Build _sha512 module
echo "=== Building _sha512 module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _sha512.cpython-310-arm-linux-gnueabi.so \
    ../Modules/sha512module.c \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _sha512 module failed"

if [ -f _sha512.cpython-310-arm-linux-gnueabi.so ]; then
    cp _sha512.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_sha512 module built successfully"
fi

# Build _blake2 module
echo "=== Building _blake2 module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _blake2.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_blake2/blake2module.c \
    ../Modules/_blake2/blake2b_impl.c \
    ../Modules/_blake2/blake2s_impl.c \
    -I../Modules/_blake2 \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _blake2 module failed"

if [ -f _blake2.cpython-310-arm-linux-gnueabi.so ]; then
    cp _blake2.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_blake2 module built successfully"
fi

# Build _sha3 module
echo "=== Building _sha3 module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _sha3.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_sha3/sha3module.c \
    -I../Modules/_sha3 \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _sha3 module failed"

if [ -f _sha3.cpython-310-arm-linux-gnueabi.so ]; then
    cp _sha3.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_sha3 module built successfully"
fi

# Build _ssl module
echo "=== Building _ssl module ==="
$CC $CFLAGS $INCLUDE_FLAGS -DPy_BUILD_CORE_MODULE -shared -fPIC \
    -o _ssl.cpython-310-arm-linux-gnueabi.so \
    ../Modules/_ssl.c \
    -I${OPENSSL_PREFIX}/include \
    -L${OPENSSL_PREFIX}/lib -lssl -lcrypto \
    $MODULE_LDFLAGS 2>&1 || echo "WARNING: _ssl module failed"

if [ -f _ssl.cpython-310-arm-linux-gnueabi.so ]; then
    cp _ssl.cpython-310-arm-linux-gnueabi.so "${PREFIX}/lib/python3.10/lib-dynload/"
    echo "_ssl module built successfully"
fi

echo ""
echo "=== Extension modules in lib-dynload ==="
ls -la "${PREFIX}/lib/python3.10/lib-dynload/"

echo "=== Done ==="
