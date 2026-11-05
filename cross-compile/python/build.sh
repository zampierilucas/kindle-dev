#!/bin/bash
set -e

# Main build script for Kindle Python 3.10+ cross-compilation
# Run this on your host machine

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="kindle-cross-compile"

echo "=== Building Docker image ==="
cd "${SCRIPT_DIR}"

# Create empty scripts dir if not exists (Docker COPY needs it)
mkdir -p scripts

# Build the Docker image
docker build -t "${IMAGE_NAME}" .

echo "=== Running cross-compilation ==="

# Create output directory
mkdir -p "${SCRIPT_DIR}/output"

# Run the container with mounted output
# Use -t only when a TTY is available
TTY_FLAG=""
[ -t 0 ] && TTY_FLAG="-t"
docker run --rm -i $TTY_FLAG \
    -v "${SCRIPT_DIR}/output:/output" \
    -v "${SCRIPT_DIR}/scripts:/scripts:ro" \
    "${IMAGE_NAME}" \
    bash -c "
        echo '=== Cross-compiler info ===' && \
        arm-kindle-linux-gnueabi-gcc --version && \
        echo '' && \
        echo '=== Starting builds ===' && \
        /scripts/01-build-openssl.sh && \
        /scripts/02-build-python.sh && \
        /scripts/03-build-deps.sh && \
        echo '' && \
        echo '=== Build complete! ===' && \
        echo 'Output in: ${SCRIPT_DIR}/output/' && \
        ls -la /output/
    "

echo ""
echo "=== Build finished ==="
echo "Output files are in: ${SCRIPT_DIR}/output/"
echo ""
echo "To deploy to Kindle:"
echo "  rsync -avz ${SCRIPT_DIR}/output/python3.10-kindle/ kindle:/mnt/us/python3.10-kindle/"
