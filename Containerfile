# Build environment for the WF2489T firmware. Pinned by digest so every build uses the same host tools.
FROM docker.io/library/debian@sha256:4876fdea29cac1a33a3195f1eb1952feb1fca7dd6dd00be3e2f1879cf20d34d2

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
# Buildroot host requirements (manual §2.1) plus what Rockchip's U-Boot needs to build.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gcc g++ make patch perl python3 python3-dev python3-setuptools \
        python3-pyelftools libssl-dev libgnutls28-dev uuid-dev swig bison flex \
        bc bzip2 cpio file findutils gzip rsync tar unzip xz-utils zstd wget curl \
        git ca-certificates libncurses-dev openssh-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
