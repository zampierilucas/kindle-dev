# Dockerfile for Kindle Python 3.10+ cross-compilation
# Uses KOReader's kindle toolchain (glibc 2.20, soft-float ABI matching Kindle's native libc)

FROM debian:bookworm-slim

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    wget \
    curl \
    git \
    bash \
    perl \
    patch \
    xz-utils \
    file \
    linux-headers-generic \
    zlib1g-dev \
    libssl-dev \
    libffi-dev \
    libncurses-dev \
    libreadline-dev \
    libbz2-dev \
    liblzma-dev \
    libsqlite3-dev \
    libexpat1-dev \
    python3 \
    python3-dev \
    python3-pip \
    rustc \
    cargo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and setup KOReader's kindle cross-compiler (glibc 2.20, soft-float ABI)
WORKDIR /opt
RUN wget -q https://github.com/koreader/koxtoolchain/releases/download/2025.05/kindle.tar.gz && \
    mkdir -p /home/root && \
    tar xzf kindle.tar.gz -C /home/root && \
    rm kindle.tar.gz

# Set up cross-compilation environment
ENV PATH="/home/root/x-tools/arm-kindle-linux-gnueabi/bin:$PATH"
ENV CROSS_COMPILE=arm-kindle-linux-gnueabi-
ENV CC=arm-kindle-linux-gnueabi-gcc
ENV CXX=arm-kindle-linux-gnueabi-g++
ENV AR=arm-kindle-linux-gnueabi-ar
ENV RANLIB=arm-kindle-linux-gnueabi-ranlib
ENV STRIP=arm-kindle-linux-gnueabi-strip
ENV HOST=arm-kindle-linux-gnueabi
ENV BUILD=x86_64-linux-gnu

# ARM-specific compiler flags matching Kindle hardware (MediaTek MT8512 / Cortex-A53)
ENV CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC"
ENV CXXFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=softfp -mtune=cortex-a53 -O2 -fPIC"
ENV LDFLAGS="-Wl,-O1"

# Create directories
RUN mkdir -p /build /output /scripts

WORKDIR /build

# Copy build scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh 2>/dev/null || true

CMD ["/bin/bash"]
