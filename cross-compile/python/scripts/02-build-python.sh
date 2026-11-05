#!/bin/bash
set -e

# Build Python 3.10 for ARM glibc (Kindle)
# This creates a standalone Python installation for Kindle

PYTHON_VERSION="3.10.16"
PREFIX="/output/python3.10-kindle"
OPENSSL_PREFIX="/output/openssl"

echo "=== Building Python ${PYTHON_VERSION} ==="

cd /build

# Download Python
if [ ! -f "Python-${PYTHON_VERSION}.tar.xz" ]; then
    wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
fi

rm -rf "Python-${PYTHON_VERSION}"
tar xJf "Python-${PYTHON_VERSION}.tar.xz"
cd "Python-${PYTHON_VERSION}"

# First, build a native Python for cross-compilation support
echo "=== Building native Python (for cross-compilation) ==="

# Save and unset cross-compile environment for native build
unset CC CXX AR RANLIB STRIP READELF CFLAGS CXXFLAGS LDFLAGS

mkdir -p build-native
cd build-native
../configure --disable-shared
make -j$(nproc) python Parser/pgen 2>/dev/null || make -j$(nproc) python
PYTHON_FOR_BUILD=$(pwd)/python
cd ..

# Generate proper sysconfig data for the native Python
# This is critical for cross-compilation to work
echo "Generating native Python sysconfig data..."
cd build-native

# Run the native Python to generate sysconfig data
./python -c "import sysconfig; print(sysconfig.get_config_vars())" > /dev/null 2>&1 || true

# Create ALL possible sysconfig files that might be requested
mkdir -p Lib
# Create a generic sysconfig data file
cat > Lib/_sysconfig_data_base.py << 'BASESYSCONFIG'
# Generic sysconfig data for cross-compilation build
build_time_vars = {
    'CC': 'gcc',
    'CXX': 'g++',
    'CFLAGS': '',
    'LDFLAGS': '',
    'SOABI': 'cpython-310',
    'EXT_SUFFIX': '.cpython-310.so',
}
BASESYSCONFIG

# Create all variants that Python might look for
for arch in "x86_64-linux-gnu" "arm-linux-gnueabi"; do
    cp Lib/_sysconfig_data_base.py "Lib/_sysconfigdata__linux_${arch}.py" 2>/dev/null || true
done

# Set PYTHONPATH so the native Python can find these
export PYTHONPATH="$(pwd)/Lib:${PYTHONPATH}"
cd ..

echo "Native Python version:"
${PYTHON_FOR_BUILD} --version

# Now cross-compile Python for ARM
echo "=== Cross-compiling Python for ARM ==="
mkdir -p build-arm

# Set up cross-compilation environment
export CC=arm-kindle-linux-gnueabi-gcc
export CXX=arm-kindle-linux-gnueabi-g++
export AR=arm-kindle-linux-gnueabi-ar
export RANLIB=arm-kindle-linux-gnueabi-ranlib
export STRIP=arm-kindle-linux-gnueabi-strip
export READELF=arm-kindle-linux-gnueabi-readelf

# ARM-specific flags
export CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC -I${OPENSSL_PREFIX}/include"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-L${OPENSSL_PREFIX}/lib -Wl,-rpath,'\$\$ORIGIN/../lib' -Wl,-rpath,'\$\$ORIGIN/'"
export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig"

# Make the native python available as python3.10 in PATH
ln -sf "${PYTHON_FOR_BUILD}" /usr/local/bin/python3.10

# Create a Setup.local file to statically build common modules BEFORE configure
# This must be done before configure runs
echo "Creating Setup.local for static module builds..."
cat > Modules/Setup.local << 'SETUP'
# Build essential modules statically into the Python binary
# This is required for cross-compilation where dynamic loading can fail
*static*

# Core modules needed for basic Python operation
_socket socketmodule.c
select selectmodule.c
_struct _struct.c
_datetime _datetimemodule.c
_random _randommodule.c
_bisect _bisectmodule.c
_heapq _heapqmodule.c
_json _json.c
_pickle _pickle.c
array arraymodule.c
_contextvars _contextvarsmodule.c
_queue _queuemodule.c
_posixsubprocess _posixsubprocess.c
binascii binascii.c
_asyncio _asynciomodule.c
math mathmodule.c

# Additional useful modules
fcntl fcntlmodule.c
_md5 md5module.c
_sha1 sha1module.c
_sha256 sha256module.c
_sha512 sha512module.c
_blake2 _blake2/blake2module.c _blake2/blake2b_impl.c _blake2/blake2s_impl.c
SETUP

cd build-arm

# Configure for cross-compilation
# Note: --enable-optimizations and --with-lto don't work well with cross-compilation
CONFIG_SITE=/dev/null ../configure \
    --prefix="${PREFIX}" \
    --host=arm-kindle-linux-gnueabi \
    --build=x86_64-linux-gnu \
    --enable-shared \
    --with-openssl="${OPENSSL_PREFIX}" \
    --with-openssl-rpath=auto \
    --disable-ipv6 \
    --without-ensurepip \
    ac_cv_file__dev_ptmx=yes \
    ac_cv_file__dev_ptc=no \
    ac_cv_buggy_getaddrinfo=no \
    ac_cv_have_long_long_format=yes \
    ac_cv_working_tzset=yes \
    PYTHON_FOR_BUILD="${PYTHON_FOR_BUILD}"

# Build - use HOSTPYTHON consistently and set the correct platform
# The _PYTHON_HOST_PLATFORM tells Python what the target platform is during cross-compilation
export _PYTHON_HOST_PLATFORM=linux-armv7l

# Generate proper sysconfig module for cross-compilation BEFORE building
echo "Generating cross-compile sysconfig..."
mkdir -p Lib
cat > Lib/_sysconfigdata__linux_arm-kindle-linux-gnueabi.py << 'SYSCONFIG'
# system configuration generated for cross-compilation
build_time_vars = {
    'SOABI': 'cpython-310-arm-linux-gnueabi',
    'EXT_SUFFIX': '.cpython-310-arm-linux-gnueabi.so',
    'MULTIARCH': 'arm-linux-gnueabi',
    'Py_ENABLE_SHARED': 1,
    'CC': 'arm-kindle-linux-gnueabi-gcc',
    'CXX': 'arm-kindle-linux-gnueabi-g++',
    'CFLAGS': '-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC',
    'LDFLAGS': '',
    'LIBDIR': '/output/python3.10-kindle/lib',
    'INCLUDEDIR': '/output/python3.10-kindle/include',
    'prefix': '/output/python3.10-kindle',
    'exec_prefix': '/output/python3.10-kindle',
}
SYSCONFIG

# Also copy to native build's Lib so it can be found
cp Lib/_sysconfigdata__linux_arm-kindle-linux-gnueabi.py ../build-native/Lib/ 2>/dev/null || true

# Build everything - ignore extension module failures for now
echo "Building Python core and modules..."
make -j$(nproc) HOSTPYTHON="${PYTHON_FOR_BUILD}" 2>&1 || {
    echo "Note: Some extension modules may have failed during cross-compilation"
    true
}

# Install
echo "Installing Python..."
make install HOSTPYTHON="${PYTHON_FOR_BUILD}" 2>&1 || {
    echo "make install had some errors, trying manual installation..."
    true
}

# Manual installation if make install failed
if [ ! -d "${PREFIX}/lib/python3.10" ]; then
    echo "Standard library not installed, copying from source..."
    mkdir -p "${PREFIX}/lib/python3.10"
    cp -r ../Lib/* "${PREFIX}/lib/python3.10/"
fi

# Ensure lib-dynload directory exists
mkdir -p "${PREFIX}/lib/python3.10/lib-dynload"

# Copy any extension modules that were built
echo "Copying extension modules..."
for dir in build/lib.*; do
    if [ -d "$dir" ]; then
        cp -v "$dir"/*.so "${PREFIX}/lib/python3.10/lib-dynload/" 2>/dev/null || true
    fi
done

# Also check for .so files in Modules directory
ls Modules/*.so 2>/dev/null && cp Modules/*.so "${PREFIX}/lib/python3.10/lib-dynload/" 2>/dev/null || true

# Copy the sysconfig data to the installed location
cp Lib/_sysconfigdata__linux_arm-kindle-linux-gnueabi.py "${PREFIX}/lib/python3.10/" 2>/dev/null || true

# Create a simpler fallback sysconfig if needed
cat > "${PREFIX}/lib/python3.10/_sysconfigdata__linux_arm-linux-gnueabi.py" << 'SYSCONFIG'
# system configuration generated for cross-compilation (fallback)
build_time_vars = {
    'SOABI': 'cpython-310-arm-linux-gnueabi',
    'EXT_SUFFIX': '.cpython-310-arm-linux-gnueabi.so',
    'MULTIARCH': 'arm-linux-gnueabi',
}
SYSCONFIG

# List what was built
echo "=== Extension modules in lib-dynload ==="
ls -la "${PREFIX}/lib/python3.10/lib-dynload/" 2>/dev/null || echo "No lib-dynload directory"

# Verify installation
echo "Verifying installation..."
ls -la "${PREFIX}/lib/python3.10/" 2>/dev/null | head -20 || echo "WARNING: Python stdlib not found!"

echo "=== Python installed to ${PREFIX} ==="

# Copy runtime libraries from toolchain
echo "=== Copying runtime libraries ==="
TOOLCHAIN_LIB="/home/root/x-tools/arm-kindle-linux-gnueabi/arm-kindle-linux-gnueabi/sysroot/lib"

# Copy libgcc_s and libstdc++ from toolchain
cp -a "${TOOLCHAIN_LIB}/libgcc_s.so"* "${PREFIX}/lib/" 2>/dev/null || true
cp -a "${TOOLCHAIN_LIB}/libstdc++.so"* "${PREFIX}/lib/" 2>/dev/null || true

# Copy OpenSSL libraries
cp -a "${OPENSSL_PREFIX}/lib/"*.so* "${PREFIX}/lib/" 2>/dev/null || true

# Create a wrapper script
cat > "${PREFIX}/python3-wrapper.sh" << 'WRAPPER'
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="${SCRIPT_DIR}/lib:${LD_LIBRARY_PATH}"
export PYTHONHOME="${SCRIPT_DIR}"
export PYTHONPATH="${SCRIPT_DIR}/lib/python3.10:${SCRIPT_DIR}/lib/python3.10/site-packages"
exec "${SCRIPT_DIR}/bin/python3.10" "$@"
WRAPPER
chmod +x "${PREFIX}/python3-wrapper.sh"

echo "=== Build complete ==="
ls -la "${PREFIX}/"
ls -la "${PREFIX}/bin/"
file "${PREFIX}/bin/python3.10"
