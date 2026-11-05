FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    xz-utils \
    bc \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    cpio \
    kmod \
    tar \
    bzip2 \
    gzip \
    file \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# releases.linaro.org retired the 4.9-2017.01 binaries (now 302s to linaro.org/contact).
# kernel.org crosstool ships the same gcc 4.9.4; the kernel builds -msoft-float either
# way, so the eabi/eabihf split does not change the module ABI.
RUN curl -L https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/4.9.4/x86_64-gcc-4.9.4-nolibc-arm-linux-gnueabi.tar.xz \
    | tar -xJ -C /opt

# gcc 4.9's cc1 wants libmpfr.so.4; bookworm ships .so.6
RUN curl -fL -o /tmp/libmpfr4.deb http://archive.debian.org/debian/pool/main/m/mpfr4/libmpfr4_3.1.5-1_amd64.deb \
    && dpkg -x /tmp/libmpfr4.deb /tmp/mpfr4 \
    && cp -a /tmp/mpfr4/usr/lib/x86_64-linux-gnu/libmpfr.so.4* /usr/lib/x86_64-linux-gnu/ \
    && rm -rf /tmp/libmpfr4.deb /tmp/mpfr4 \
    && ldconfig

ENV PATH=/opt/gcc-4.9.4-nolibc/arm-linux-gnueabi/bin:$PATH
ENV ARCH=arm
ENV CROSS_COMPILE=arm-linux-gnueabi-

WORKDIR /work
