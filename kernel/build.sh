#!/bin/sh
# Mainline kernel for the WF2489T as Debian packages (runs in the build container).
# arm64 defconfig + kernel/config.fragment, board DTS from dts/, kernel/patches/*.
# Output: out/kernel/linux-image-*.deb, linux-headers-*.deb, the Wi-Fi driver
# and linux-image-wf2489t (depends on both, so apt upgrade gets new kernels).
# Version: date of the last commit that changed kernel/ or dts/.
set -eu
REPO=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
TAG=v7.4-rc1
COMMIT=6628e7d4c6b25c8d18f1345e3a20d21829aae7e4

SRC=build/linux OBJ=build/linux-obj
if [ ! -d $SRC/.git ]; then
	git init -q $SRC
	git -C $SRC fetch -q --depth 1 $REPO tag $TAG
fi
[ "$(git -C $SRC rev-parse $TAG^{commit})" = $COMMIT ] || { echo "$TAG is not $COMMIT"; exit 1; }

# pristine tree + our changes (unchanged files keep their mtime, so rebuilds stay incremental)
git -C $SRC checkout -q --detach $COMMIT
git -C $SRC reset -q --hard
git -C $SRC clean -q -fdx
for p in kernel/patches/*.patch; do [ -e "$p" ] || continue; git -C $SRC apply "$PWD/$p"; done
cp dts/rk3576s-wf2489t.dtsi dts/rk3576s-wf2489t.dts $SRC/arch/arm64/boot/dts/rockchip/
echo 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3576s-wf2489t.dtb' >> $SRC/arch/arm64/boot/dts/rockchip/Makefile

# reproducible: build date and package version from the last kernel commit
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct -- kernel dts)
VERSION=$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d.%H%M -- kernel dts)
# no "-dirty" from the patched git tree in the kernel release (scripts/setlocalversion)
export GIT_DIR=/nonexistent
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KBUILD_BUILD_USER=wf2489t KBUILD_BUILD_HOST=build \
	KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)"
mkdir -p $OBJ
make -s -C $SRC O=$PWD/$OBJ defconfig
$SRC/scripts/kconfig/merge_config.sh -m -O $OBJ $OBJ/.config kernel/config.fragment >/dev/null
make -s -C $SRC O=$PWD/$OBJ olddefconfig
rm -f build/*.deb build/*.buildinfo build/*.changes
make -s -C $SRC O=$PWD/$OBJ -j$(nproc) LOCALVERSION=-wf2489t KDEB_PKGVERSION=$VERSION bindeb-pkg

mkdir -p out/kernel && rm -f out/kernel/*.deb
cp build/linux-image-*-wf2489t_${VERSION}_arm64.deb build/linux-headers-*_${VERSION}_arm64.deb out/kernel/

# Wi-Fi/BT: AIC8800D80 SDIO driver (out of tree) from Radxa's DKMS package,
# built against this kernel and packaged for it; firmware: debian/build-image.sh
AIC_VERSION=5.0+git20260123.5f7be68d-10
AIC_DEB=aic8800-sdio-dkms_${AIC_VERSION}_all.deb
AIC_SHA256=9dcf24ef5bc5417e06c059d786518728a6439212f457b8c31593f2765e6f95a2
AIC=build/aic8800 KREL=$(cat $OBJ/include/config/kernel.release)
mkdir -p build/dl
[ -f build/dl/$AIC_DEB ] || curl -sSfL -o build/dl/$AIC_DEB \
	https://github.com/radxa-pkg/aic8800/releases/download/$AIC_VERSION/$AIC_DEB
echo "$AIC_SHA256  build/dl/$AIC_DEB" | sha256sum -c --quiet
rm -rf $AIC && mkdir -p $AIC && dpkg-deb -x build/dl/$AIC_DEB $AIC/deb
AIC_SRC=$AIC/deb/usr/src/aic8800-sdio-$AIC_VERSION
for p in kernel/aic8800/*.patch; do [ -e "$p" ] || continue; patch -s -p1 -d $AIC_SRC < $p; done
make -s -C $SRC O=$PWD/$OBJ M=$PWD/$AIC_SRC/SDIO/driver_fw/driver/aic8800 -j$(nproc) modules
make -s -C $SRC O=$PWD/$OBJ M=$PWD/$AIC_SRC/SDIO/driver_fw/driver/aic8800 \
	INSTALL_MOD_PATH=$PWD/$AIC/pkg INSTALL_MOD_DIR=updates/aic8800 INSTALL_MOD_STRIP=1 DEPMOD=true modules_install
rm -f $AIC/pkg/lib/modules/$KREL/modules.*
mkdir -p $AIC/pkg/DEBIAN
cat > $AIC/pkg/DEBIAN/control <<CONTROL
Package: aic8800-sdio-modules-$KREL
Version: $VERSION
Architecture: arm64
Maintainer: wf2489t-firmware
Depends: linux-image-$KREL, aic8800-firmware (= $AIC_VERSION)
Section: kernel
Priority: optional
Description: AIC8800 SDIO Wi-Fi/Bluetooth driver for Linux $KREL
 Radxa's aic8800 driver (radxa-pkg/aic8800 $AIC_VERSION), built for the
 WF2489T kernel $KREL.
CONTROL
printf '#!/bin/sh\nset -e\ndepmod -a %s\n' $KREL > $AIC/pkg/DEBIAN/postinst
cp $AIC/pkg/DEBIAN/postinst $AIC/pkg/DEBIAN/postrm
chmod 755 $AIC/pkg/DEBIAN/postinst $AIC/pkg/DEBIAN/postrm
dpkg-deb --root-owner-group -Zxz --build $AIC/pkg out/kernel/aic8800-sdio-modules-${KREL}_${VERSION}_arm64.deb >/dev/null

# linux-image-wf2489t: always the current kernel and its Wi-Fi driver
M=build/linux-meta
rm -rf $M && mkdir -p $M/DEBIAN
cat > $M/DEBIAN/control <<CONTROL
Package: linux-image-wf2489t
Version: $VERSION
Architecture: arm64
Maintainer: wf2489t-firmware
Depends: linux-image-$KREL (= $VERSION), aic8800-sdio-modules-$KREL (= $VERSION)
Section: kernel
Priority: optional
Description: Linux kernel for the WF2489T (meta package)
 Depends on the current mainline kernel for the WF2489T and its Wi-Fi driver.
CONTROL
dpkg-deb --root-owner-group -Zxz --build $M out/kernel/linux-image-wf2489t_${VERSION}_arm64.deb >/dev/null
ls -l out/kernel
