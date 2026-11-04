#!/bin/sh
# Debian trixie image for the WF2489T, built with the debos container (needs
# /dev/kvm; no binfmt setup on the host). Run "make kernel" first.
# Output: out/wf2489t-debian.img (disk image, one ext4 partition labelled "root")
#         out/root.ext4 (that partition alone, for writing to the tablet)
set -eu
cd "$(dirname "$0")/.."
ls out/kernel/linux-image-*.deb >/dev/null 2>&1 || { echo "no kernel package, run: make kernel"; exit 1; }
rm -rf debian/kdeb && mkdir -p debian/kdeb out
cp out/kernel/linux-image-*.deb out/kernel/aic8800-sdio-modules-*.deb debian/kdeb/

# AIC8800 Wi-Fi/BT firmware (Radxa), same version as the driver in out/kernel
AIC_VERSION=5.0+git20260123.5f7be68d-10
AIC_FW=aic8800-firmware_${AIC_VERSION}_all.deb
AIC_FW_SHA256=0b7c5e229a4214f738e260cfdca45dc934abb5079890c709346577126dba94f8
mkdir -p build/dl
[ -f build/dl/$AIC_FW ] || curl -sSfL -o build/dl/$AIC_FW \
	https://github.com/radxa-pkg/aic8800/releases/download/$AIC_VERSION/$AIC_FW
echo "$AIC_FW_SHA256  build/dl/$AIC_FW" | sha256sum -c --quiet
cp build/dl/$AIC_FW debian/kdeb/

# TouchKio: Home Assistant kiosk app (Electron), default kiosk browser
TK_VERSION=1.6.0
TK_DEB=touchkio_${TK_VERSION}_arm64.deb
TK_SHA256=24ef7856a6e9d7ac66201015b2d2895bc642d1ea9d86d957f9142df28958891f
[ -f build/dl/$TK_DEB ] || curl -sSfL -o build/dl/$TK_DEB \
	https://github.com/leukipp/touchkio/releases/download/v$TK_VERSION/$TK_DEB
echo "$TK_SHA256  build/dl/$TK_DEB" | sha256sum -c --quiet
cp build/dl/$TK_DEB debian/kdeb/

podman run --rm --device /dev/kvm --group-add keep-groups --userns keep-id \
	--security-opt label=disable --tmpfs /scratch:exec,size=8g \
	-v "$PWD:/work" -w /work ghcr.io/go-debos/debos:latest \
	--scratchsize=8G --artifactdir=out debian/wf2489t.yaml

dd if=out/wf2489t-debian.img of=out/root.ext4 bs=1M skip=1 status=none
rm -rf debian/kdeb
sha256sum out/root.ext4
