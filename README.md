# WF2489T firmware

Mainline U-Boot, a mainline kernel and Debian for the WF2489T, a 15.6" wall
tablet with a Rockchip RK3576S (vendor board "R141 V10"), so it can be used
like a generic Linux machine. The tablet is unbranded (bought from an Alibaba
seller); its stock Android reports brand "Apolosign", manufacturer "Electron".

## Build

```sh
make uboot     # out/uboot-copy1.img
make kernel    # out/kernel/linux-image-*.deb, linux-headers-*.deb
make image     # out/wf2489t-debian.img and out/root.ext4 (needs /dev/kvm)
make all
```

Needs `make` and `podman`. U-Boot and the kernel build in the container from
`Containerfile` (Debian trixie, pinned by digest); the image is built with the
[debos](https://github.com/go-debos/debos) container. Sources are fetched into
`build/` and checked against the pinned commits.

Login: `root` / `admin` (console, serial, SSH). Network: Ethernet, DHCP.

## Install

1. U-Boot (once, or to update it): write `out/uboot-copy1.img` to sector 16384
   (copy 1 of the `uboot` area) from maskrom (Ctrl+B on the debug UART at
   power-on, then `tools/rk_maskrom_boot.py` with Rockchip's usbplug and
   `rkdeveloptool wl 16384 out/uboot-copy1.img`).
2. Debian: stop U-Boot at its prompt (debug UART), run `ums 0 mmc 0`; the eMMC
   appears on the PC as a USB disk. Then as root on the PC:

   ```sh
   tools/install-root.sh /dev/sdX out/root.ext4 [kiosk URL]
   ```

   It writes a GPT with only `uboot` and `root` (loader at sector 64 and vendor
   storage at sector 7168 stay untouched), installs the root filesystem and
   grows it. Ctrl+C at the U-Boot prompt ends `ums`; `boot` starts Debian.

The same `ums` path is the recovery for a broken root filesystem.

## What is pinned

| Input | Version | Where |
| --- | --- | --- |
| Linux | v7.4-rc1 (`6628e7d4c6b2`) + `kernel/patches/` | `kernel/build.sh` |
| U-Boot | v2026.10 (`5508406582f6`) + `uboot/patches/` | `uboot/build.sh` |
| TF-A (BL31) | master `ba48f2d3b4d2` + `tf-a/patches/` | `uboot/build.sh` |
| Debian | trixie | `debian/wf2489t.yaml` |
| Build tools | Debian trixie by digest | `Containerfile` |

## Boot chain

| Stage | Where on the eMMC | Source |
| --- | --- | --- |
| DDR init + SPL (stock, Ctrl+B on the debug UART → maskrom) | sector 64 | stock, never written |
| TF-A BL31 + U-Boot (FIT) | `uboot` partition, copy 1 (sector 16384) | `make uboot` |
| fallback FIT | `uboot` partition, copy 2 | stock, never written |
| kernel, initramfs, DTB via `extlinux.conf` | root filesystem, `/boot` | Debian + `make kernel` |

U-Boot boots the first partition with the GPT "legacy BIOS bootable" flag that
has `/boot/extlinux/extlinux.conf`; Debian's `u-boot-menu` keeps that file up to
date on kernel updates. The root filesystem is found by its label `root`.

## Layout

| Path | Contents |
| --- | --- |
| `dts/` | board device tree, used by both Linux and U-Boot |
| `kernel/` | config fragment, patches, build script |
| `uboot/` | defconfig, U-Boot DT additions, FIT generator, build script (U-Boot + TF-A) |
| `tf-a/` | TF-A patches |
| `debian/` | debos recipe, first-boot setup, config overlay |
| `tools/` | maskrom loader (`rk_maskrom_boot.py`), `/dev/mem` register tool (`rr.c`) |
| `docs/` | notes, e.g. the eMMC timing and kernel bug analysis (`docs/emmc.md`) |

## Upstream TF-A and the stock loader

The stock SPL arms the secure watchdog (`wdt_s`, ~11 s) for its A/B boot
counting and leaves it running. Rockchip's BL31 stops it; upstream TF-A did
not, so the tablet reset every 7–12 s. `tf-a/patches/0001` pauses it at BL31
start, as TF-A already does for system suspend. With that, Rockchip's BL31 and
OP-TEE are no longer needed (and the 16 MiB OP-TEE reservation is gone).

## Kernel patches

| Patch | Status |
| --- | --- |
| `0001` RK3576 eMMC HS400 timing from Rockchip's BSP kernel | local |
| `0003`-`0007` RK3576 PWMv4 (Collabora, v5, not merged yet), `0008` its 7.4 adaptation | local |
| `0002` mmc core: single-block recovery flag never cleared | [sent upstream](https://lore.kernel.org/linux-mmc/?q=s%3A%22clear+MQRQ_XFER_SINGLE_BLOCK+for+new+requests%22) |

## Status

- [x] Mainline U-Boot + upstream TF-A (no Rockchip binaries after the stock SPL, no OP-TEE), automatic extlinux boot
- [x] Mainline kernel: display, touch, GPU, eMMC (HS400ES), Ethernet, PCIe, sensors, RTC, keys
- [x] Debian trixie image (debos), kernel as a Debian package
- [x] Ethernet MAC address from Rockchip vendor storage (U-Boot, passed to Linux in the device tree)
- [x] LED ring red/green/blue (on/off), relays on I/O 3 and 4 (`gpioset -t 0 relay-1=1`)
- [ ] Zigbee/Thread (EFR32 on `ttyS6`): not fitted on the test unit (no answer on UART6), untested
- [x] Wi-Fi (AIC8800D80 on SDIO, 2.4 + 5 GHz): Radxa's driver built with the kernel (`kernel/aic8800/`), firmware package pinned
- [x] Sound: speaker playback via ES8388 on SAI1 (48 and 44.1 kHz)
- [ ] Built-in microphone (ES7202 PDM ADC, no mainline driver)
- [x] PWM (Collabora PWMv4 series, kernel/patches 0003-0008): backlight dimming (`/sys/class/backlight/backlight`), RGB LED ring with colour mixing and dimming (`/sys/class/leds/rgb:status`, `multi_intensity`)
- [x] Kiosk: `kiosk.service` runs cage + cog (WPE WebKit) full screen on the display; URL in `/etc/default/kiosk`
- [ ] Kiosk GPU acceleration: WPE's web process renders in software so far (no `/dev/dri` in its sandbox)
- [x] U-Boot USB mass storage: `ums 0 mmc 0` at the U-Boot prompt shows the whole eMMC on the PC (uboot/patches 0002, 0003)
- [x] Final partition table: `uboot` + one `root` partition (installed on the test tablet with U-Boot `gpt write` + `gzwrite`, or `tools/install-root.sh` via `ums`)
