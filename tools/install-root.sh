#!/bin/sh
# install-root.sh DEVICE [ROOT_IMAGE] [KIOSK_URL]
#
# Install Debian on the tablet's eMMC from the PC. Start the tablet into the
# U-Boot prompt (debug UART) and run "ums 0 mmc 0": the eMMC shows up on the
# PC as a USB disk ("UMS disk 0"). Then, as root:
#
#   tools/install-root.sh /dev/sdX out/root.ext4 [https://kiosk.page]
#
# Writes a new GPT with only
#   1 uboot  sectors 16384-24575 (4 MiB, content kept: our FIT + stock copy 2)
#   2 root   sector 24576 to the end, "legacy BIOS bootable" for U-Boot
# then the root filesystem (grown to the whole partition). The stock loader
# (sector 64) and Rockchip vendor storage (sector 7168, MAC address) are
# outside all partitions and are not touched.
set -eu
dev=${1:?usage: install-root.sh DEVICE [ROOT_IMAGE] [KIOSK_URL]}
img=${2:-out/root.ext4}
url=${3:-}

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
[ -b "$dev" ] && [ -f "$img" ] || { echo "no block device $dev or no image $img" >&2; exit 1; }

# only the tablet's eMMC exported by U-Boot ums
tran=$(lsblk -dno TRAN "$dev"); model=$(lsblk -dno MODEL "$dev" | sed 's/ *$//')
size=$(blockdev --getsize64 "$dev")
[ "$tran" = usb ] && [ "$model" = "UMS disk 0" ] || { echo "$dev is not U-Boot ums ($tran, $model)" >&2; exit 1; }
[ "$size" -gt $((8 * 1024 * 1024 * 1024)) ] || { echo "$dev is too small" >&2; exit 1; }
# Rockchip idblock ("RKNS") at sector 64: the stock loader is in place
magic=$(dd if="$dev" bs=512 skip=64 count=1 status=none | head -c 4)
[ "$magic" = RKNS ] || { echo "no Rockchip loader at sector 64 of $dev" >&2; exit 1; }

echo "This replaces the partition table and ALL partitions of $dev ($model, $((size / 1000000000)) GB)"
echo "except the U-Boot area, and installs $img."
printf 'Type yes to continue: '; read answer; [ "$answer" = yes ] || exit 1

for p in "$dev"?*; do umount "$p" 2>/dev/null || true; done

sgdisk --clear \
	--new=1:16384:24575 --change-name=1:uboot --typecode=1:8301 \
	--new=2:24576:0 --change-name=2:root --typecode=2:8305 --attributes=2:set:2 \
	"$dev"
partprobe "$dev" 2>/dev/null || blockdev --rereadpt "$dev"
udevadm settle
root=$(lsblk -lnpo NAME "$dev" | sed -n 3p)
[ -b "$root" ] || { echo "root partition did not appear" >&2; exit 1; }

echo "writing $img to $root"
dd if="$img" of="$root" bs=4M conv=fsync status=progress
e2fsck -f -y "$root" >/dev/null || [ $? -le 1 ]
resize2fs "$root"

if [ -n "$url" ]; then
	mnt=$(mktemp -d)
	mount "$root" "$mnt"
	sed -i "s|^KIOSK_URL=.*|KIOSK_URL=$url|" "$mnt/etc/default/kiosk"
	umount "$mnt"; rmdir "$mnt"
	echo "kiosk page: $url"
fi
sync
sgdisk --print "$dev"
echo "done: stop ums on the tablet (Ctrl+C at the U-Boot prompt) and boot"
