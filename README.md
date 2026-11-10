# WF2489T firmware

Mainline U-Boot, a mainline kernel and Debian for the WF2489T, a 15.6" wall
tablet with a Rockchip RK3576S (vendor board "R141 V10"), so it can be used
like a generic Linux machine. The tablet is unbranded (bought from an Alibaba
seller); its stock Android reports brand "Apolosign", manufacturer "Electron".

## Build

```sh
make uboot     # out/uboot-copy1.img
make kernel    # out/kernel/*.deb: kernel, Wi-Fi driver, linux-image-wf2489t
make repo      # out/repo: apt repository (wf2489t package, kernel, firmware, TouchKio)
make image     # out/wf2489t-debian.img and out/root.ext4 (needs /dev/kvm)
make all
```

Needs `make` and `podman`. U-Boot and the kernel build in the container from
`Containerfile` (Debian trixie, pinned by digest); the image is built with the
[debos](https://github.com/go-debos/debos) container. Sources are fetched into
`build/` and checked against the pinned commits.

Login: `root` / `admin` (console, serial, SSH). Network: Ethernet, DHCP.

## Install

Prebuilt images: [Releases](https://github.com/Fexiven/wf2489t-firmware/releases)
(`root.ext4.xz`, `uboot-copy1.img`, `SHA256SUMS`). Or build them with `make`.

1. U-Boot: write `out/uboot-copy1.img` to copy 1 of the `uboot` area
   (sector 16384) and, once it has booted, as the known-good fallback to
   copy 2 (sector 20480). With our U-Boot running: on the tablet
   `wf2489t-write-uboot [--copy2] uboot-copy1.img`, or in USB mode (step 2)
   on the PC `tools/write-uboot.sh [--copy2] out/uboot-copy1.img /dev/sdX`;
   both check the image, write only that copy and read it back. The stock
   U-Boot has the same USB mode (`ums 0 mmc 0` at its prompt). On a stock
   tablet without USB mode: maskrom (Ctrl+B on the debug UART at power-on,
   then `tools/rk_maskrom_boot.py` with Rockchip's usbplug and
   `rkdeveloptool wl 16384 out/uboot-copy1.img`).
2. Debian: connect the tablet's USB port to the PC and hold the power key at
   power-on for about 3 s: the LED ring turns blue and the eMMC appears on the
   PC as a USB disk ("UMS disk 0"; also `ums 0 mmc 0` at the U-Boot prompt).
   Then as root on the PC (needs `sgdisk`, `e2fsck`, `resize2fs`):

   ```sh
   tools/install-root.sh /dev/sdX out/root.ext4 \
       KIOSK_URL=http://homeassistant.local:8123 KIOSK_MQTT_URL=mqtt://broker.local:1883
   ```

   It writes a GPT with only `uboot` and `root` (loader at sector 64 and vendor
   storage at sector 7168 stay untouched), installs the root filesystem and
   grows it. Ctrl+C on the debug UART or the reset pinhole ends USB mode, and
   the tablet boots Debian.

The same USB mode is the recovery for a broken root filesystem.

The LED ring shows the U-Boot state: green while booting (Linux turns it off),
blue in USB mode, red if nothing could be booted. Debian shows a boot splash
(Plymouth, Debian logo); kernel and systemd messages go to the debug UART.

## Updates

Everything for the tablet is in Debian packages from this repository's apt
repository (`make repo`; CI publishes it on GitHub Pages, signed):

| Package | Contents |
| --- | --- |
| `wf2489t` | kiosk (labwc, TouchKio, squeekboard), MQTT service, udev and sudo rules, Bluetooth, network; depends on all of the below |
| `linux-image-wf2489t` | the current kernel and its AIC8800 Wi-Fi driver |
| `aic8800-firmware`, `touchkio` | Radxa's firmware and TouchKio, pinned versions |
| `mesa-teflon-rk3576` | the TensorFlow Lite delegate for the NPU (see [NPU](#npu)) |
| `wf2489t-person-runtime` | LiteRT interpreter (from Google's wheel) and the EfficientDet-Lite0 model for the person sensor |

The image installs `wf2489t`, which also adds the repository, so the tablet
updates with `apt update && apt upgrade`. A package's version is the date of
the last commit that changed its sources (`package/`; `kernel/` and `dts/` for
the kernel; `teflon/` for `mesa-teflon-rk3576`; `person/` for
`wf2489t-person-runtime`). Kiosk settings stay in
`/etc/default/kiosk`.

## What is pinned

| Input | Version | Where |
| --- | --- | --- |
| Linux | v7.4-rc1 (`6628e7d4c6b2`) + `kernel/patches/` | `kernel/build.sh` |
| Mesa (Teflon, NPU) | [gahingwoo/mesa-rk3576](https://github.com/gahingwoo/mesa-rk3576) `1f0de937b711` + `teflon/patches/` | `teflon/build.sh` |
| U-Boot | v2026.10 (`5508406582f6`) + `uboot/patches/` | `uboot/build.sh` |
| TF-A (BL31) | master `ba48f2d3b4d2` + `tf-a/patches/` | `uboot/build.sh` |
| Debian | trixie (current point release) | `debian/wf2489t.yaml` |
| AIC8800 firmware, TouchKio | by SHA-256 | `debian/build-repo.sh` |
| LiteRT 2.3.0 wheel, EfficientDet-Lite0 (Mesa 26.2.6 tests) | by SHA-256 | `person/build.sh` |
| Build tools | Debian trixie by digest | `Containerfile` |

## Boot chain

| Stage | Where on the eMMC | Source |
| --- | --- | --- |
| DDR init + SPL (stock, Ctrl+B on the debug UART → maskrom) | sector 64 | stock, never written |
| TF-A BL31 + U-Boot (FIT) | `uboot` partition, copy 1 (sector 16384) | `make uboot` |
| fallback FIT (the stock SPL loads it when copy 1 fails its hash check) | `uboot` partition, copy 2 (sector 20480) | `make uboot`, known-good version (stock: `backup/uboot.img`, second half) |
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
| `teflon/` | the `mesa-teflon-rk3576` package: Mesa patches for the NPU, build script |
| `person/` | the `wf2489t-person-runtime` package: build script (pinned LiteRT wheel and model) |
| `package/` | the `wf2489t` package: kiosk and board support files, maintainer scripts |
| `debian/` | apt repository builder, debos recipe for the image |
| `tools/` | installer (`install-root.sh`), U-Boot writer (`write-uboot.sh`), maskrom loader (`rk_maskrom_boot.py`), `/dev/mem` register tool (`rr.c`) |
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
| `0009`-`0011` front camera: GC5035 driver (ChromeOS, ported), MIPI DC-PHY receive mode, CSI-2 receiver in receive mode | local |
| `0012`-`0013` VICAP (rkcif): stop the DMA before the source, no reset in runtime suspend (both hung the bus on stream stop) | local |
| `0003`-`0007` RK3576 PWMv4 (Collabora, v5, not merged yet), `0008` its 7.4 adaptation | local |
| `npu/` RK3576 NPU for the `rocket` driver: Jiaxing Hu's series v16 and the rk3576-npu-open patches (see [NPU](#npu)) | not merged yet |
| `0002` mmc core: single-block recovery flag never cleared | [sent upstream](https://lore.kernel.org/linux-mmc/?q=s%3A%22clear+MQRQ_XFER_SINGLE_BLOCK+for+new+requests%22) |

## NPU

The RK3576 NPU (2 cores) runs with the open stack from
[rk3576-npu-open](https://github.com/Fexiven/rk3576-npu-open): the mainline
`rocket` driver with the RK3576 series and fixes (`kernel/patches/npu/`, built
as the module `rocket`, `/dev/accel/accel0`) and Mesa's Teflon delegate for
TensorFlow Lite with the RK3576 patches (`mesa-teflon-rk3576`). The board DTS
enables both cores with the stock OPP table: devfreq scales the NPU between
300 and 950 MHz and parks it at 200 MHz with the rail off when idle. Both
parts are temporary until they are upstream.

The person sensor uses it (`wf2489t-person.service`). Own models in TensorFlow
Lite / LiteRT, e.g. with `ai-edge-litert` from PyPI:

```python
from ai_edge_litert import interpreter as tfl
npu = tfl.load_delegate("/usr/lib/teflon-rk3576/libteflon.so")
it = tfl.Interpreter(model_path="model.tflite", experimental_delegates=[npu])
```

## Status

- [x] Mainline U-Boot + upstream TF-A (no Rockchip binaries after the stock SPL, no OP-TEE), automatic extlinux boot
- [x] Mainline kernel: display, touch, GPU, eMMC (HS400ES, 290 MB/s read, 176 MB/s write, no CRC errors; the data strobe needs a pull-down, see `docs/emmc.md`), Ethernet, PCIe, sensors, RTC, keys
- [x] Debian trixie image (debos), everything else as Debian packages from our apt repository
- [x] Ethernet MAC address from Rockchip vendor storage (U-Boot, passed to Linux in the device tree)
- [x] LED ring red/green/blue (on/off), relays on I/O 3 and 4 (`gpioset -t 0 relay-1=1`)
- [ ] Zigbee/Thread (EFR32 on `ttyS6`): not fitted on the test unit; stock Android's own tool (`lmiot-efr32`) gets no answer either (`ezspForceReset 0x21`)
- [x] Wi-Fi (AIC8800D80 on SDIO, 2.4 + 5 GHz): Radxa's driver built with the kernel (`kernel/aic8800/`), firmware package pinned
- [x] Sound: speaker playback via ES8388 on SAI1 (48 and 44.1 kHz)
- [x] Bluetooth (AIC8800D80 on `ttyS4`, H4 at 1.5 Mbaud): `aic8800-bluetooth.service` attaches it with btattach; BR/EDR + LE scan tested
- [x] Front camera (GC5035 on the MIPI DC-PHY, kernel/patches 0009-0011): raw Bayer capture via VICAP (`/dev/video0`, 1296x972); no ISP, so exposure and colours are set in software
- [ ] Built-in microphone: 4 PDM microphones on PDM1 (SDI0-3; stock uses `simple-audio-card` with a dummy codec, 16 kHz, gain 87; pins pdm1m0 clk0/sdi0 + pdm1m1 clk1/sdi1/sdi2). Mainline `rockchip_pdm` has no RK3576 entry and `rk3576.dtsi` no PDM node yet
- [x] PWM (Collabora PWMv4 series, kernel/patches 0003-0008): backlight dimming (`/sys/class/backlight/backlight`), RGB LED ring with colour mixing and dimming (`/sys/class/leds/rgb:status`, `multi_intensity`)
- [x] Kiosk: `kiosk.service` runs labwc + [TouchKio](https://github.com/leukipp/touchkio) (Electron, fullscreen, dark, maximized while the on-screen keyboard squeekboard is shown); URL and MQTT broker in `/etc/default/kiosk`
- [x] Hardware watchdog (systemd, 44 s: a hung system resets itself; tested with a kernel crash), journal limited to 50 MB, Debian security and point-release updates installed automatically (unattended-upgrades)
- [x] Automatic display brightness from the ambient light sensor (`wf2489t-autobrightness.service`, off with `KIOSK_AUTO_BRIGHTNESS=no` in `/etc/default/kiosk`)
- [x] Home Assistant via MQTT (with `KIOSK_MQTT_URL`): TouchKio's display power/brightness (`wlopm`, backlight), volume, keyboard, sensors; the RGB LED ring as a light and the ambient light sensor (`wf2489t-mqtt.service`); a person sensor from the front camera (`wf2489t-person.service`: EfficientDet-Lite0 on the NPU, one check per second, nothing on the CPU; Person in room / near / count / score; switches the display off after 5 min without a person and on when someone is in the room; software auto exposure with only the sensor's working gain steps and 1x digital gain; `KIOSK_PERSON*` in `/etc/default/kiosk`); the processor temperature (TouchKio does not know the RK3576 thermal zone names); reboot/shutdown via a sudo rule
- [x] Kiosk GPU acceleration (Electron's GPU process uses Panfrost)
- [x] NPU: both cores with clock scaling, TensorFlow Lite via Mesa Teflon (`mesa-teflon-rk3576`, see [NPU](#npu))
- [x] U-Boot USB mass storage: power key held at power-on (or `ums 0 mmc 0` at the prompt) shows the whole eMMC on the PC (uboot/patches 0001-0003)
- [x] U-Boot status on the LED ring (green booting, blue USB mode, red boot failure); Debian boot splash
- [x] Final partition table: `uboot` + one `root` partition (installed on the test tablet with U-Boot `gpt write` + `gzwrite`, or `tools/install-root.sh` via `ums`)
