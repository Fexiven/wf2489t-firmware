#!/bin/sh
# Mainline U-Boot + upstream TF-A for the WF2489T (runs in the build container).
# FIT = TF-A BL31 + U-Boot + DTB, loaded by the stock SPL from copy 1 of the
# "uboot" partition (sector 16384). Copy 2 stays stock as fallback.
# Output: out/uboot-copy1.img (2 MiB)
set -eu
UBOOT_REPO=https://source.denx.de/u-boot/u-boot.git
UBOOT_TAG=v2026.10
UBOOT_COMMIT=5508406582f6f7120dce0c4b3059819a41788db2
TFA_REPO=https://github.com/ARM-software/arm-trusted-firmware.git
TFA_COMMIT=ba48f2d3b4d2ddbced021cf6ecbc95938e27f2a1

SRC=build/u-boot OBJ=build/u-boot-obj TFA=build/tf-a FIT=build/fit

# pristine sources at the pinned commits + our patches
fetch() {  # fetch DIR REPO REF COMMIT
	if [ ! -d $1/.git ]; then
		git init -q $1
		git -C $1 fetch -q --depth 1 $2 $3
	fi
	git -C $1 checkout -q --detach $4 && git -C $1 reset -q --hard && git -C $1 clean -q -fdx
	[ "$(git -C $1 rev-parse HEAD)" = $4 ] || { echo "$1 is not at $4"; exit 1; }
}
fetch $SRC $UBOOT_REPO "tag $UBOOT_TAG" $UBOOT_COMMIT
fetch $TFA $TFA_REPO $TFA_COMMIT $TFA_COMMIT
for p in uboot/patches/*.patch; do [ -e "$p" ] || continue; git -C $SRC apply "$PWD/$p"; done
for p in tf-a/patches/*.patch; do [ -e "$p" ] || continue; git -C $TFA apply "$PWD/$p"; done
cp dts/rk3576s-wf2489t.dtsi uboot/rk3576s-wf2489t.dts uboot/rk3576s-wf2489t-u-boot.dtsi $SRC/arch/arm/dts/
cp uboot/wf2489t-rk3576_defconfig $SRC/configs/

# reproducible: build date from the last commit that changed U-Boot, TF-A or
# the DTS; no "-dirty" from the patched source trees in the version strings
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct -- uboot tf-a dts)
export CROSS_COMPILE=aarch64-linux-gnu-

# TF-A BL31 (no BL32/OP-TEE)
make -s -C $TFA PLAT=rk3576 BUILD_BASE=$PWD/build/tf-a-obj BUILD_STRING=$(echo $TFA_COMMIT | cut -c1-7) -j$(nproc) bl31
BL31=$PWD/build/tf-a-obj/rk3576/release/bl31/bl31.elf

# U-Boot; u-boot-rockchip.bin (would need Rockchip's DDR blob) is not used
mkdir -p $OBJ
make -s -C $SRC O=$PWD/$OBJ wf2489t-rk3576_defconfig
GIT_DIR=/nonexistent make -s -C $SRC O=$PWD/$OBJ -j$(nproc) BL31=$BL31 BINMAN_ALLOW_MISSING=1 2>&1 \
	| grep -v -E "WARNING: Missing|missing (optional|external)|rockchip-tpl|tee-os|See the documentation|Trusted Execution|Some images are invalid|external TPL|binary and build with ROCKCHIP_TPL|for the external TPL binary|^\s*$" || true
[ -f $OBJ/u-boot-nodtb.bin ] || { echo "U-Boot build failed"; exit 1; }

# FIT, 512-byte aligned (the stock SPL reports "Bad hash" on unaligned images)
rm -rf $FIT && mkdir -p $FIT
cp $OBJ/u-boot-nodtb.bin $OBJ/u-boot.dtb $FIT/
python3 uboot/make-fit-its.py $BL31 $FIT 0x$(grep -E '^CONFIG_TEXT_BASE=' $OBJ/.config | sed 's/.*=0x//')
(cd $FIT && PATH=$PWD/../../$OBJ/scripts/dtc:$PATH ../../$OBJ/tools/mkimage -f u-boot.its -E -B 0x200 -p 0x1400 uboot.itb >/dev/null)
mkdir -p out
head -c 2097152 /dev/zero > out/uboot-copy1.img
dd if=$FIT/uboot.itb of=out/uboot-copy1.img conv=notrunc status=none
sha256sum out/uboot-copy1.img
