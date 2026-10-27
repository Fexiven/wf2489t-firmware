#!/bin/sh
# WF2489T post-image: pack the U-Boot FIT for copy 1 of the `uboot` partition.
#
# Same layout as the known-good image: U-Boot, BL31 split per load address,
# OP-TEE and the U-Boot dtb, packed with the U-Boot tree's own mkimage
# (-E -p 0x1400, as Rockchip's fit-core.sh). Never produces an idbloader or
# u-boot-rockchip.bin: the stock loader and vendor storage are not ours to write.
set -eu

BOARD_DIR="$(dirname "$0")"
FIT_DIR="$BINARIES_DIR/fit"
SLOT_SIZE=2097152    # each U-Boot copy in the `uboot` partition is 2 MiB

rm -rf "$FIT_DIR"
mkdir -p "$FIT_DIR"
cp "$BINARIES_DIR/u-boot-nodtb.bin" "$BINARIES_DIR/u-boot.dtb" "$FIT_DIR/"
cp "$BINARIES_DIR/rkbin/tee.bin" "$FIT_DIR/"
python3 "$BOARD_DIR/split-bl31.py" "$BINARIES_DIR/rkbin/bl31.elf" "$FIT_DIR"
cp "$BOARD_DIR/u-boot.its" "$FIT_DIR/"

# mkimage and dtc from the U-Boot tree itself (Rockchip's dtc), as the vendor packing does
UBOOT_BUILD="$(ls -d "$BUILD_DIR"/uboot-* | head -n 1)"
(cd "$FIT_DIR" && PATH="$UBOOT_BUILD/scripts/dtc:$PATH" "$UBOOT_BUILD/tools/mkimage" -f u-boot.its -E -p 0x1400 uboot.itb)

size="$(stat -c %s "$FIT_DIR/uboot.itb")"
if [ "$size" -ge "$SLOT_SIZE" ]; then
	echo "post-image: uboot.itb is $size bytes, does not fit the 2 MiB slot" >&2
	exit 1
fi

# 2 MiB image for copy 1, zero-padded like the known-good uboot-copy1-net.img
head -c "$SLOT_SIZE" /dev/zero > "$BINARIES_DIR/uboot-copy1.img"
dd if="$FIT_DIR/uboot.itb" of="$BINARIES_DIR/uboot-copy1.img" conv=notrunc status=none
echo "post-image: uboot-copy1.img (FIT $size bytes)"
