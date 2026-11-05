#!/bin/bash
set -euo pipefail

# Usage: build-uhid.sh <profile> [kernel-config]
# Profiles: koa3-5.18.2, basic2-5.16.2.1.1
# kernel-config: optional /proc/config.gz (or plain .config) pulled off the
# target device, used instead of the in-tree defconfig.

PROFILE="${1:-koa3-5.18.2}"
CONFIG_SRC="${2:-}"

case "$PROFILE" in
    koa3-5.18.2)
        TARBALL="Kindle_src_5.18.2_4434550025.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_v7_zelda_defconfig"
        OUT_NAME="uhid-4.1.15-lab126-5.18.2-zelda.ko"
        ;;
    ko2-5.16.2.1.1)
        TARBALL="Kindle_src_5.16.2.1.1_4097450002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_v7_zelda_defconfig"
        OUT_NAME="uhid-4.1.15-lab126-5.16.2.1.1-ko2.ko"
        ;;
    pw4-5.16.2.1.1)
        TARBALL="Kindle_src_5.16.2.1.1_4097540002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_rex_defconfig"
        OUT_NAME="uhid-4.1.15-lab126-435186-rex.ko"
        ;;
    rex-5.12.4)
        TARBALL="Kindle_src_5.12.4_3602780042.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_rex_defconfig"
        OUT_NAME="uhid-4.1.15-lab126-360278-rex.ko"
        ;;
    rex-5.10.1.3)
        TARBALL="Kindle_src_5.10.1.3_3372830002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-rex.tar.gz"
        DEFCONFIG="imx_rex_defconfig"
        OUT_NAME="uhid-4.1.15-lab126-337283-rex.ko"
        ;;
    rex-5.18.1.1.1)
        TARBALL="Kindle_src_5.18.1.1.1_4769670023.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-4.1.15.tar.gz"
        DEFCONFIG="imx_rex_defconfig"
        OUT_NAME="uhid-4.1.15-lab126-476967-rex.ko"
        ;;
    basic2-5.16.2.1.1)
        TARBALL="Kindle_src_5.16.2.1.1_4097490002.tar.gz"
        URL="https://s3.amazonaws.com/kindledownloads/${TARBALL}"
        KERNEL_TARBALL="linux-3.10.53.tar.gz"
        DEFCONFIG="imx_wario_defconfig"
        OUT_NAME="uhid-3.10.53-lab126-5.16.2.1.1-basic2.ko"
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        echo "Available: koa3-5.18.2, basic2-5.16.2.1.1"
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

CONFIG_STEP='make $MAKE_FLAGS '"$DEFCONFIG"
if [ -n "$CONFIG_SRC" ]; then
    echo "==> Using kernel config $CONFIG_SRC"
    case "$CONFIG_SRC" in
        *.gz) gzip -dc "$CONFIG_SRC" > "$WORK/.config" ;;
        *)    cp "$CONFIG_SRC" "$WORK/.config" ;;
    esac
    CONFIG_STEP="echo 'using supplied .config'"
fi

echo "==> Building image (if needed)"
if ! docker image inspect kindle-kernel-cross >/dev/null 2>&1; then
    docker build -t kindle-kernel-cross "$SCRIPT_DIR"
else
    echo "==> Using cached kindle-kernel-cross image"
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

echo "==> Building uhid.ko"
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
        echo '--- config'
        $CONFIG_STEP
        echo '--- enabling CONFIG_UHID=m, disabling drivers with missing proprietary sources'
        scripts/config --module CONFIG_UHID
        scripts/config --disable CONFIG_FB_MXC_EINK_V2_PANEL
        scripts/config --disable CONFIG_FB_MXC_EINK_PANEL
        make \$MAKE_FLAGS olddefconfig
        echo '--- modules_prepare'
        make \$MAKE_FLAGS modules_prepare
        echo '--- vmlinux build (CRCs for built-in symbols like module_layout)'
        make \$MAKE_FLAGS -j\$(nproc) vmlinux
        echo '--- modules build (CRCs for module-exported symbols)'
        make \$MAKE_FLAGS -j\$(nproc) modules
        echo '--- building uhid (with proper CRCs now)'
        make \$MAKE_FLAGS M=drivers/hid modules
        echo '--- modinfo'
        modinfo drivers/hid/uhid.ko || true
        cp drivers/hid/uhid.ko /work/output/$OUT_NAME
        echo '--- output:'
        ls -la /work/output/$OUT_NAME
    "

echo "==> Done: output/$OUT_NAME"
