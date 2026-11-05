/*
 * Simple gamepad/input event reader for Kindle Alpine Linux
 * Reads raw input events from /dev/input/eventX devices
 *
 * Usage: ./gamepad_reader /dev/input/event0
 *
 * Cross-compile with:
 *   arm-linux-gnueabi-gcc -static -march=armv7-a -o gamepad_reader gamepad_reader.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/input.h>
#include <errno.h>
#include <sys/ioctl.h>

/* Event type names */
const char* get_type_name(int type) {
    switch(type) {
        case EV_SYN: return "SYN";
        case EV_KEY: return "KEY";
        case EV_REL: return "REL";
        case EV_ABS: return "ABS";
        case EV_MSC: return "MSC";
        default: return "???";
    }
}

/* Common gamepad button names */
const char* get_key_name(int code) {
    switch(code) {
        case BTN_A: return "BTN_A/SOUTH";
        case BTN_B: return "BTN_B/EAST";
        case BTN_X: return "BTN_X/NORTH";
        case BTN_Y: return "BTN_Y/WEST";
        case BTN_TL: return "BTN_TL (L1)";
        case BTN_TR: return "BTN_TR (R1)";
        case BTN_TL2: return "BTN_TL2 (L2)";
        case BTN_TR2: return "BTN_TR2 (R2)";
        case BTN_SELECT: return "BTN_SELECT";
        case BTN_START: return "BTN_START";
        case BTN_MODE: return "BTN_MODE";
        case BTN_THUMBL: return "BTN_THUMBL (L3)";
        case BTN_THUMBR: return "BTN_THUMBR (R3)";
        case BTN_DPAD_UP: return "DPAD_UP";
        case BTN_DPAD_DOWN: return "DPAD_DOWN";
        case BTN_DPAD_LEFT: return "DPAD_LEFT";
        case BTN_DPAD_RIGHT: return "DPAD_RIGHT";
        default: return NULL;
    }
}

/* Common axis names */
const char* get_abs_name(int code) {
    switch(code) {
        case ABS_X: return "LEFT_X";
        case ABS_Y: return "LEFT_Y";
        case ABS_Z: return "L2_TRIGGER";
        case ABS_RX: return "RIGHT_X";
        case ABS_RY: return "RIGHT_Y";
        case ABS_RZ: return "R2_TRIGGER";
        case ABS_HAT0X: return "DPAD_X";
        case ABS_HAT0Y: return "DPAD_Y";
        default: return NULL;
    }
}

void print_device_info(int fd) {
    char name[256] = "Unknown";
    struct input_id id;

    ioctl(fd, EVIOCGNAME(sizeof(name)), name);
    printf("Device name: %s\n", name);

    if (ioctl(fd, EVIOCGID, &id) == 0) {
        printf("Vendor: 0x%04x  Product: 0x%04x  Version: 0x%04x\n",
               id.vendor, id.product, id.version);
    }
    printf("-------------------------------------------\n");
}

void list_devices(void) {
    char path[64];
    char name[256];
    int fd;

    printf("Available input devices:\n");
    for (int i = 0; i < 32; i++) {
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        fd = open(path, O_RDONLY);
        if (fd >= 0) {
            name[0] = '\0';
            ioctl(fd, EVIOCGNAME(sizeof(name)), name);
            printf("  %s: %s\n", path, name);
            close(fd);
        }
    }
    printf("\n");
}

int main(int argc, char *argv[]) {
    struct input_event ev;
    int fd;
    const char *device;

    if (argc < 2) {
        printf("Gamepad Input Reader for Kindle\n\n");
        list_devices();
        printf("Usage: %s /dev/input/eventX\n", argv[0]);
        printf("       %s -l              (list devices only)\n", argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "-l") == 0) {
        list_devices();
        return 0;
    }

    device = argv[1];
    fd = open(device, O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "Error opening %s: %s\n", device, strerror(errno));
        return 1;
    }

    printf("Reading from: %s\n", device);
    print_device_info(fd);
    printf("Press Ctrl+C to exit\n\n");

    while (1) {
        ssize_t n = read(fd, &ev, sizeof(ev));
        if (n != sizeof(ev)) {
            if (n < 0) perror("read");
            break;
        }

        /* Skip sync events for cleaner output */
        if (ev.type == EV_SYN)
            continue;

        const char *type_name = get_type_name(ev.type);

        if (ev.type == EV_KEY) {
            const char *key_name = get_key_name(ev.code);
            if (key_name) {
                printf("[%s] %s = %d (%s)\n", type_name, key_name, ev.value,
                       ev.value ? "PRESSED" : "RELEASED");
            } else {
                printf("[%s] code=%d value=%d\n", type_name, ev.code, ev.value);
            }
        } else if (ev.type == EV_ABS) {
            const char *abs_name = get_abs_name(ev.code);
            if (abs_name) {
                printf("[%s] %s = %d\n", type_name, abs_name, ev.value);
            } else {
                printf("[%s] code=%d value=%d\n", type_name, ev.code, ev.value);
            }
        } else {
            printf("[%s] code=%d value=%d\n", type_name, ev.code, ev.value);
        }
    }

    close(fd);
    return 0;
}
