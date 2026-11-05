#!/bin/sh
#
# Simple gamepad event reader using hexdump
# Works without any compilation - just needs busybox hexdump
#
# Usage: ./gamepad_hexdump.sh /dev/input/event0
#
# Input event structure (32-bit ARM):
#   tv_sec:  4 bytes
#   tv_usec: 4 bytes
#   type:    2 bytes
#   code:    2 bytes
#   value:   4 bytes
#   Total:   16 bytes per event

DEVICE="${1:-/dev/input/event0}"

if [ ! -e "$DEVICE" ]; then
    echo "Device $DEVICE not found"
    echo ""
    echo "Available input devices:"
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            name=$(cat /sys/class/input/$(basename $dev)/device/name 2>/dev/null || echo "unknown")
            echo "  $dev: $name"
        fi
    done
    exit 1
fi

echo "Reading from: $DEVICE"
echo "Press Ctrl+C to exit"
echo "Format: type code value"
echo "---"

# Read 16-byte input events and decode
hexdump -v -e '8/1 "%02x " "| " 2/1 "%02x " "| " 2/1 "%02x " "| " 4/1 "%02x " "\n"' "$DEVICE" | \
while read -r timestamp sep1 type sep2 code sep3 value; do
    # Convert little-endian hex to decimal
    type_dec=$(printf "%d" 0x${type% *}${type#* })
    code_hex="${code% *}${code#* }"
    code_dec=$(printf "%d" 0x$code_hex)

    # Skip SYN events (type 0)
    [ "$type_dec" = "0" ] && continue

    # Decode type
    case "$type_dec" in
        1) type_name="KEY" ;;
        2) type_name="REL" ;;
        3) type_name="ABS" ;;
        4) type_name="MSC" ;;
        *) type_name="T$type_dec" ;;
    esac

    # Get value (handle signed 32-bit)
    val_hex=$(echo "$value" | tr -d ' ')
    val_dec=$(printf "%d" 0x$val_hex 2>/dev/null || echo "?")

    echo "[$type_name] code=$code_dec ($code_hex) value=$val_dec"
done
