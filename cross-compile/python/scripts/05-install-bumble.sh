#!/bin/bash
set -e

# Install Bumble and pure-Python dependencies
# Most Bumble deps are pure Python and don't need cross-compilation

PREFIX="/output/python3.10-kindle"
WHEELS="/output/wheels"

echo "=== Installing Bumble and dependencies ==="

# Create a requirements file with versions compatible with Bumble 0.0.220
cat > /build/requirements.txt << 'EOF'
# Core Bumble (latest)
bumble>=0.0.220

# Pure Python dependencies (no native code)
pyee>=13.0.0
websockets>=15.0.1
prompt_toolkit>=3.0.16
prettytable>=3.6.0
protobuf>=3.12.4
appdirs>=1.4
platformdirs>=3.10.0
humanize>=4.6.0
click>=8.1.3

# Native dependencies (need cross-compiled wheels)
# cryptography>=44.0.3  # Built separately
# aiohttp~=3.8  # Built separately
# grpcio>=1.62.1  # Built separately (optional, can be skipped)
EOF

# For now, we'll just download the pure-Python packages
# The native ones need special handling

pip3 download \
    --platform linux_armv7l \
    --python-version 310 \
    --only-binary=:none: \
    --no-deps \
    -d "${WHEELS}" \
    pyee \
    websockets \
    prompt_toolkit \
    prettytable \
    protobuf \
    appdirs \
    platformdirs \
    humanize \
    click \
    wcwidth \
    typing_extensions \
    || true

echo "=== Downloaded packages ==="
ls -la "${WHEELS}/"

echo ""
echo "=== NOTE ==="
echo "Native packages (cryptography, aiohttp, grpcio) need to be built separately"
echo "or their prebuilt wheels need to be sourced for armv7l musl"
