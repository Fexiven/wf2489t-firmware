#!/bin/sh
# The apt repository (flat, signed) for the tablet, in out/repo:
#   wf2489t                  board support + kiosk (package/)
#   linux-image-wf2489t ...  kernel and Wi-Fi driver (make kernel)
#   mesa-teflon-rk3576       Mesa Teflon delegate for the NPU (teflon/)
#   wf2489t-person-runtime   LiteRT interpreter + model for the person sensor (person/)
#   aic8800-firmware         Radxa, pinned
#   touchkio                 Home Assistant kiosk app, pinned
# Signed with the key in $WF2489T_SIGNING_KEY (armored secret key) if set;
# CI publishes it on GitHub Pages. Runs in the build container.
set -eu
cd "$(dirname "$0")/.."
ls out/kernel/linux-image-wf2489t_*.deb >/dev/null 2>&1 || { echo "no kernel packages, run: make kernel"; exit 1; }
rm -rf out/repo && mkdir -p out/repo build/dl
sh package/build.sh
sh teflon/build.sh
sh person/build.sh
cp out/kernel/linux-image-*.deb out/kernel/aic8800-sdio-modules-*.deb out/repo/

# fetch NAME URL SHA256
fetch() {
	[ -f build/dl/$1 ] || curl -sSfL -o build/dl/$1 $2
	echo "$3  build/dl/$1" | sha256sum -c --quiet
	cp build/dl/$1 out/repo/
}
# AIC8800 Wi-Fi/BT firmware: same version as the driver in kernel/build.sh
AIC_VERSION=5.0+git20260123.5f7be68d-10
fetch aic8800-firmware_${AIC_VERSION}_all.deb \
	https://github.com/radxa-pkg/aic8800/releases/download/$AIC_VERSION/aic8800-firmware_${AIC_VERSION}_all.deb \
	0b7c5e229a4214f738e260cfdca45dc934abb5079890c709346577126dba94f8
TK_VERSION=1.6.0
fetch touchkio_${TK_VERSION}_arm64.deb \
	https://github.com/leukipp/touchkio/releases/download/v$TK_VERSION/touchkio_${TK_VERSION}_arm64.deb \
	24ef7856a6e9d7ac66201015b2d2895bc642d1ea9d86d957f9142df28958891f

cd out/repo
apt-ftparchive packages . > Packages
gzip -9nkf Packages
apt-ftparchive -o APT::FTPArchive::Release::Origin=wf2489t \
	-o APT::FTPArchive::Release::Label=wf2489t release . > Release
cp ../../package/root/usr/share/keyrings/wf2489t.gpg .
if [ -n "${WF2489T_SIGNING_KEY:-}" ]; then
	export GNUPGHOME=$(mktemp -d)
	printf '%s\n' "$WF2489T_SIGNING_KEY" | gpg -q --batch --import
	gpg -q --batch --clearsign -o InRelease Release
	gpg -q --batch -abs -o Release.gpg Release
	rm -rf "$GNUPGHOME"
else
	echo "WF2489T_SIGNING_KEY not set: repository not signed (fine for make image)"
fi
ls -l
