#!/bin/sh
# Debian trixie image for the WF2489T, built with the debos container (needs
# /dev/kvm; no binfmt setup on the host). Run "make kernel" first.
# Output: out/wf2489t-debian.img (disk image, one ext4 partition labelled "root")
#         out/root.ext4 (that partition alone, for writing to the tablet)
set -eu
cd "$(dirname "$0")/.."
ls out/kernel/linux-image-*.deb >/dev/null 2>&1 || { echo "no kernel package, run: make kernel"; exit 1; }
rm -rf debian/kdeb && mkdir -p debian/kdeb out
cp out/kernel/linux-image-*.deb debian/kdeb/

podman run --rm --device /dev/kvm --group-add keep-groups --userns keep-id \
	--security-opt label=disable --tmpfs /scratch:exec,size=8g \
	-v "$PWD:/work" -w /work ghcr.io/go-debos/debos:latest \
	--scratchsize=8G --artifactdir=out debian/wf2489t.yaml

dd if=out/wf2489t-debian.img of=out/root.ext4 bs=1M skip=1 status=none
rm -rf debian/kdeb
sha256sum out/root.ext4
