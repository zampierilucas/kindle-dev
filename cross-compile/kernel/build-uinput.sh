#!/bin/bash
set -euo pipefail

# Usage: build-uinput.sh <profile>
# Profiles: koa3-5.18.2, ko2-5.16.2.1.1, pw4-5.16.2.1.1, rex-5.18.1.1.1, basic2-5.16.2.1.1

PROFILE="${1:-koa3-5.18.2}"

case "$PROFILE" in
    koa3-5.18.2)
        TARBALL="Kindle_src_5.18.2_4434550025.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_v7_zelda_defconfig"
        OUT_NAME="uinput-4.1.15-lab126-5.18.2-zelda.ko"
        ;;
    ko2-5.16.2.1.1)
        TARBALL="Kindle_src_5.16.2.1.1_4097450002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_v7_zelda_defconfig"
        OUT_NAME="uinput-4.1.15-lab126-5.16.2.1.1-ko2.ko"
        ;;
    pw4-5.16.2.1.1)
        TARBALL="Kindle_src_5.16.2.1.1_4097540002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_rex_defconfig"
        OUT_NAME="uinput-4.1.15-lab126-435186-rex.ko"
        ;;
    rex-5.18.1.1.1)
        TARBALL="Kindle_src_5.18.1.1.1_4769670023.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_rex_defconfig"
        OUT_NAME="uinput-4.1.15-lab126-476967-rex.ko"
        ;;
    basic2-5.16.2.1.1)
        TARBALL="Kindle_src_5.16.2.1.1_4097490002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-3.10.53.tar.gz"
        DEFCONFIG="imx_wario_defconfig"
        OUT_NAME="uinput-3.10.53-lab126-5.16.2.1.1-basic2.ko"
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        echo "Available: koa3-5.18.2, ko2-5.16.2.1.1, pw4-5.16.2.1.1, rex-5.18.1.1.1, basic2-5.16.2.1.1"
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "tarballs/$TARBALL" ]; then
    echo "==> Downloading $TARBALL"
    wget -O "tarballs/$TARBALL" "$URL"
else
    echo "==> Using cached tarballs/$TARBALL"
fi

WORK="source/$PROFILE"
if [ ! -f "$WORK/Makefile" ] || ! grep -q "PATCHLEVEL = " "$WORK/Makefile" 2>/dev/null; then
    echo "==> Extracting outer tarball"
    mkdir -p "$WORK"
    tar xf "tarballs/$TARBALL" -C "$WORK"
    NESTED=$(find "$WORK" -name "$KERNEL_TARBALL" | head -1)
    if [ -z "$NESTED" ]; then
        echo "ERROR: $KERNEL_TARBALL not found in $TARBALL"
        find "$WORK" -name 'linux-*.tar.*' | head
        exit 1
    fi
    echo "==> Extracting kernel from $NESTED"
    tar xf "$NESTED" -C "$WORK"
else
    echo "==> Using existing source/$PROFILE"
fi

echo "==> Building image (if needed)"
if ! docker image inspect kindle-kernel-cross >/dev/null 2>&1; then
    docker build -t kindle-kernel-cross "$SCRIPT_DIR"
else
    echo "==> Using cached kindle-kernel-cross image"
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

echo "==> Building uinput.ko"
docker run --rm \
    -v "$SCRIPT_DIR/source:/work/source" \
    -v "$SCRIPT_DIR/output:/work/output" \
    -e HOST_UID="$HOST_UID" \
    -e HOST_GID="$HOST_GID" \
    kindle-kernel-cross bash -c "
        trap 'chown -R \$HOST_UID:\$HOST_GID /work/source/$PROFILE /work/output 2>/dev/null || true' EXIT
        set -euo pipefail
        cd /work/source/$PROFILE
        echo '--- compiler-gcc shims for modern GCC'
        for n in 6 7 8 9 10 11 12 13 14 15; do
            ln -sf compiler-gcc5.h include/linux/compiler-gcc\$n.h
        done
        MAKE_FLAGS='KBUILD_HOSTCFLAGS=-fcommon HOSTCFLAGS=-fcommon KCFLAGS=-march=armv7-a'
        echo '--- defconfig: $DEFCONFIG'
        make \$MAKE_FLAGS $DEFCONFIG
        echo '--- enabling CONFIG_INPUT_UINPUT=m, disabling drivers with missing proprietary sources'
        scripts/config --enable CONFIG_INPUT_MISC
        scripts/config --module CONFIG_INPUT_UINPUT
        scripts/config --disable CONFIG_FB_MXC_EINK_V2_PANEL
        scripts/config --disable CONFIG_FB_MXC_EINK_PANEL
        make \$MAKE_FLAGS olddefconfig
        echo '--- confirming CONFIG_INPUT_UINPUT'
        grep CONFIG_INPUT_UINPUT .config
        echo '--- modules_prepare'
        make \$MAKE_FLAGS modules_prepare
        echo '--- vmlinux build (CRCs for built-in symbols like module_layout)'
        make \$MAKE_FLAGS -j\$(nproc) vmlinux
        echo '--- modules build (CRCs for module-exported symbols)'
        make \$MAKE_FLAGS -j\$(nproc) modules
        echo '--- building uinput (with proper CRCs now)'
        make \$MAKE_FLAGS M=drivers/input/misc modules
        echo '--- modinfo'
        modinfo drivers/input/misc/uinput.ko || true
        cp drivers/input/misc/uinput.ko /work/output/$OUT_NAME
        echo '--- output:'
        ls -la /work/output/$OUT_NAME
    "

echo "==> Done: output/$OUT_NAME"
