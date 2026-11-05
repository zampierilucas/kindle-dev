# Kindle kernel module cross-compile

Local one-off builds against Amazon's GPL kernel source.

```sh
./build-uhid.sh koa3-5.18.2                    # 4.1.15-lab126, KOA3/KO2/PW4/KOA/Basic 3
./build-uhid.sh basic2-5.16.2.1.1              # 3.10.53-lab126, Basic 2
./build-uhid.sh rex-5.12.4 config-360278.gz    # build against a device's /proc/config.gz
```

Output: `output/uhid-*.ko`.

Tarball cache in `tarballs/`, extracted sources in `source/<profile>/`. Both gitignored.

## Before shipping a module

The in-tree defconfig is not always the config the device shipped with, and
Amazon's tarball name is not always the source inside it (`Kindle_src_5.12.4`
unpacks to `Kindle_src_5.12.3_3581490036`). Either one puts different symbol
CRCs in the module and insmod refuses it. Check the CRCs against a stock module
pulled off the target device:

```sh
diff <(/sbin/modprobe --dump-modversions output/uhid-....ko | sort -k2) \
     <(/sbin/modprobe --dump-modversions stock-from-device.ko | sort -k2)
```

Only the symbols both modules import matter; `module_layout` and the `dev_*`
helpers are in every module and are the ones that usually disagree.
