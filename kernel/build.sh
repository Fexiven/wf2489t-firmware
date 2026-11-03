#!/bin/sh
# Mainline kernel for the WF2489T as Debian packages (runs in the build container).
# arm64 defconfig + kernel/config.fragment, board DTS from dts/, kernel/patches/*.
# Output: out/kernel/linux-image-*.deb, linux-headers-*.deb
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

# reproducible: build date = date of the last commit of this repo
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || echo 0)
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KBUILD_BUILD_USER=wf2489t KBUILD_BUILD_HOST=build \
	KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)"
mkdir -p $OBJ
make -s -C $SRC O=$PWD/$OBJ defconfig
$SRC/scripts/kconfig/merge_config.sh -m -O $OBJ $OBJ/.config kernel/config.fragment >/dev/null
make -s -C $SRC O=$PWD/$OBJ olddefconfig
rm -f build/*.deb build/*.buildinfo build/*.changes
make -s -C $SRC O=$PWD/$OBJ -j$(nproc) LOCALVERSION=-wf2489t KDEB_PKGVERSION=1 bindeb-pkg

mkdir -p out/kernel && rm -f out/kernel/*.deb
cp build/linux-image-*-wf2489t_1_arm64.deb build/linux-headers-*_arm64.deb out/kernel/
ls -l out/kernel
