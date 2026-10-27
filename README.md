# WF2489T firmware

Reproducible firmware for the Apolosign WF2489T wall tablet (Rockchip RK3576), built with
[Buildroot](https://buildroot.org) 2026.02.3 LTS as a `BR2_EXTERNAL` tree inside a pinned podman container.

## Build

```sh
nix-shell --run make        # on NixOS; elsewhere just `make` (needs make, curl, podman)
```

Outputs land in `output/images/`. Other targets: `make menuconfig`, `make savedefconfig`, `make shell`,
and `make br-<target>` for any Buildroot target (e.g. `make br-linux-rebuild`).

GitHub Actions (`.github/workflows/build.yml`) runs the same build on every push; the images are
attached to each run as artifacts.

Baseline login: `root` / `admin` (screen and SSH). Network: Ethernet with DHCP; Wi-Fi comes later.

## What is pinned

| Input | Where |
| --- | --- |
| Host tools | `Containerfile` (Debian trixie-slim by digest) |
| Buildroot release | `Makefile` (`BR_VERSION`, `BR_SHA256`) |
| Toolchain, packages, kernel/U-Boot sources | `external/configs/wf2489t_defconfig` and package `.hash` files |

## Layout on the tablet (target)

| Region | Contents |
| --- | --- |
| first 4 MiB | stock partition table, loader, vendor storage: **never written** |
| `uboot` | copy 1: our Rockchip U-Boot (safety net, A/B boot counting); copy 2: stock |
| `system_a`, `system_b` | read-only system (SquashFS), updated with RAUC |
| `data` | settings and state, kept across updates |

## Status

1. [x] Project skeleton, toolchain build
2. [x] U-Boot (Rockchip next-dev + safety net, rkbin pinned): `output/images/uboot-copy1.img`, byte-reproducible; FIT matches the known-good image except the U-Boot binary (different compiler)
3. [x] Kernel (Rockchip develop-6.1 + WF2489T device tree + AIC8800): `Image`, `rk3576s-wf2489t.dtb`, Wi-Fi modules + firmware; builds, not yet booted on the tablet
4. [ ] Baseline Linux (BusyBox init, SSH, Ethernet) booting on the tablet
5. [ ] RAUC A/B updates
