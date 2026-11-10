# Build tools for the WF2489T firmware (kernel packages, U-Boot, Mesa Teflon).
# Pinned by digest so every build, local or in CI, uses the same compilers and
# tools.
FROM docker.io/library/debian@sha256:4876fdea29cac1a33a3195f1eb1952feb1fca7dd6dd00be3e2f1879cf20d34d2

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN dpkg --add-architecture arm64 && apt-get update && apt-get install -y --no-install-recommends \
        build-essential crossbuild-essential-arm64 bc bison flex cpio kmod rsync \
        git ca-certificates curl python3 python3-dev python3-setuptools \
        python3-pyelftools python3-libfdt swig device-tree-compiler \
        libssl-dev libssl-dev:arm64 libgnutls28-dev uuid-dev libelf-dev libdw-dev \
        dpkg-dev debhelper-compat apt-utils gnupg \
        meson ninja-build pkgconf python3-mako python3-yaml python3-packaging \
        libdrm-dev:arm64 libexpat1-dev:arm64 zlib1g-dev:arm64 libzstd-dev:arm64 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
