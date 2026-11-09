# eMMC on the WF2489T (RK3576): HS400ES in Linux, 52 MHz in U-Boot

eMMC: manfid 0x32, oemid 0x0101, name `MMC64G`, prv 0x51, fw 0x06, made
11/2025, eMMC 5.1, 58.5 GiB, 1.6 MB write cache. No-name chip (marking only
says "eMMC"); the vendor is not identifiable.

## Linux (mainline 7.4-rc1): two patches, see `patches/`

**0001 – RK3576 HS400 DLL settings from Rockchip's BSP kernel.** Mainline uses
"revision 1" 90° values for RK3576 that are wrong for this board: command
timeouts, command and data CRC errors, an I/O error with data loss during a
3 GB write. Stock Android (Rockchip 6.1, `rk3576_drvdata`) runs the same
HS400ES with: tx tap 7, cmdout tap 7 (both clock edges), strobe tap 5,
RXCLK ORI_GATE, and all four DLL registers carrying `DLL_TAP_VALUE_SEL` with
tap = DLL lock value × 2 (`RK_TAP_VALUE_SEL`), DDR50 strobe delay 10.
The patch adds these to `rockchip_pltfm_data`, set only for RK3576.
Result: command errors 0, no bus resets, data intact.

**0002 – mmc core bug: single-block recovery flag never cleared.** After a
transfer error the block layer sets `MQRQ_XFER_SINGLE_BLOCK` in the request
PDU; nothing clears it, and PDUs are reused per tag. Every tag that saw one
error issues CMD17/CMD24 forever. Symptom: ~200 MB/s right after boot,
dropping to 3–10 MB/s within minutes; the host registers show CMD17 with
512-byte blocks, ~1 interrupt per sector. Introduced in 7.1 by d34124edffdb; still unfixed in mainline master
(checked 2026-11-03). Fix: clear `flags` together with `retries` in
`mmc_mq_queue_rq()`. Sent upstream 2026-11-03 as "[PATCH] mmc: core: clear
MQRQ_XFER_SINGLE_BLOCK for new requests" (to
Ulf Hansson, Cc linux-mmc, linux-kernel, stable):
https://lore.kernel.org/linux-mmc/?q=s%3A%22clear+MQRQ_XFER_SINGLE_BLOCK+for+new+requests%22

With both patches: reads ~200 MB/s, writes 60–90 MB/s, stable over time.
(barebox measured 170 MB/s read / 22 MB/s write on RK3576/RK3588.)

Remaining: ~1 data CRC error per 10–15 MB written, all retried without
data loss. Sweeps of the TX tap (3–12) and strobe tap (1–9) at runtime show
no effect at all (13–27 errors per 256 MB for every value), so it is not a
delay-line timing issue; the BSP values stay. Reads are error free at every
strobe tap tested.

Measured again 2026-11-09 (Debian image, kernel 20261104.1210, HS400ES at
198 MHz): 14 GB sequential write (~49 MB/s) and read-back (298 MB/s) with 0
checksum mismatches, then 2 min fio 4k random read/write with crc32c
verification, 4 jobs, iodepth 16 (read 3686 IOPS, write 2790 IOPS, err=0).
`err_stats` after 18 GiB written: 1123 data CRC errors (~1 per 16 MB),
everything else 0; nothing in dmesg (the retries are silent). So the
remaining write CRC errors are unchanged, and still without data loss.

**HS200 instead (2026-11-09, now the default in `dts/`).** Same test with only
`mmc-hs400-1_8v`/`mmc-hs400-enhanced-strobe` replaced by `mmc-hs200-1_8v`
(198 MHz SDR, tuned): 17 GiB written, `err_stats` all 0, 0 mismatches, fio
err=0.

| | HS400ES | HS200 |
| --- | --- | --- |
| data CRC errors | 1123 / 18 GiB | 0 / 17 GiB |
| sequential write | ~49 MB/s | 141 MB/s |
| sequential read | 298 MB/s | 166 MB/s |
| 4k random read / write | 3686 / 2790 IOPS | 3945 / 3029 IOPS |

HS400 reads use the card's data strobe and are clean; the errors are on
writes, where the card samples on the host clock at double data rate. The
pin configuration (pull-up, drive level 2; strobe no pull) and the DLL taps
are the same as on stock Android, and the TX tap sweep had no effect, so the
margin on this board/chip is likely electrical. Stock Android was measured
afterwards (below): it runs HS400ES without errors, so the board can do it.

**Stock Android, same unit (2026-11-09).** Android 14 userdebug, vendor
kernel 6.1.75, eMMC = `mmc1`: HS400 enhanced strobe, 200.0 MHz, CQE enabled.
8 GB written to /data with sync: 151 MB/s, 0 mismatches, `err_stats` data CRC
0 over 10.4 GiB written. The clocks are the same as in mainline: card clock
`cclk_src_emmc` from CPLL at 200 MHz, bclk/hclk 198 MHz, aclk 297 MHz (the
"actual clock 198 MHz" in mainline's `ios` is only sdhci's calculated value).
Pin configuration and DLL taps are the same as ours too. Remaining
differences: CQE (on in Android, times out in mainline) and the vendor
driver's internals (rockchip-linux develop-6.1 `sdhci-of-dwcmshc.c`), not yet
compared line by line. Raw data:
`info/android-emmc-2026-11-09.txt` (outside the repo). Patch 0001 stays (HS200 tuning on RK3576 uses the same DLL
setup).

Runtime tuning tool: a tiny static `/dev/mem` reader/writer (`rr ADDR...`,
`rr -w ADDR VALUE`), built from scratch (no libc); DLL registers at
0x2a330804 (RXCLK), 0x808 (TXCLK), 0x80c (STRBIN), 0x810 (CMDOUT),
error counters in `/sys/kernel/debug/mmc0/err_stats`.

## U-Boot: 52 MHz for now

U-Boot runs the eMMC at 52 MHz (`max-frequency = <52000000>`, no
HS200/HS400 in `rk3576s-wf2489t-u-boot.dtsi`); tested 6/6 cold boots, costs
~1–2 s per boot.

Mainline U-Boot (v2026.10) HS200/HS400ES is unreliable here. Its RK3576 tap
values already match the BSP (tx 7, cmdout 7, strbin 5, ORI_GATE,
BOTH_CLK_EDGE) but it lacks the DLL lock tap value and `MISC_INTCLK_EN`.
Likely fix (untested): add `FLAG_TAPVALUE_FROM_SW` to `rk3576_data` in
`drivers/mmc/rockchip_sdhci.c` (already implemented for RK3528) and set
`MISC_INTCLK_EN` (0x81c bit 1) after reset.

Register dump at 0x2a330000, HS400ES @ 200 MHz:

| Register          | U-Boot     | Linux unpatched | Linux 0001 (= BSP) |
|-------------------|------------|-----------------|--------------------|
| DLL_RXCLK 0x804   | 0x88000000 | 0x08000000      | 0x8a006200         |
| DLL_TXCLK 0x808   | 0x29000007 | 0x2900000a      | 0x2b006207         |
| DLL_STRBIN 0x80c  | 0x09000005 | 0x09000004      | 0x0b006205         |
| DLL_CMDOUT 0x810  | 0x59000007 | 0x39000008      | 0x5b006207         |
| MISC_CON 0x81c    | 0x1        | 0x3             | 0x3                |
| HOST_CTRL3 0x508  | 0x000f0000 | 0x000f0010      | 0x000f0010         |


## Cause found: the data strobe needs a pull-down (2026-11-09)

The remaining HS400 "write CRC errors" were not a write problem. In HS400 the
card drives the data strobe (DS), and the host also samples the CRC status
token after every written block with it. Between transfers the card releases
DS. Mainline `rk3576.dtsi` configures `emmc_strb` with `pcfg_pull_none`, so the
line floats and the CRC status is misread; the block is retried and the data
is intact, but writes drop to ~50 MB/s. The pad reset value is pull-down,
stock Android keeps it (its sdhci node has no `pinctrl-0` at all), and
`rk3588-base-pinctrl.dtsi` uses `pcfg_pull_down` for the same pin.

Found by leaving the eMMC pads at their reset values (no pinctrl in U-Boot and
Linux): 0 errors. Then each value was put back to mainline's at runtime
(VCCIO_IOC 0x26046114, write-mask register, 2 bits per pin):

| change from the reset values | data CRC errors per GiB | write |
| --- | --- | --- |
| none | 0 | 179 MB/s |
| strobe pull-down -> none (mainline) | 65 | 75 MB/s |
| CLK pull-down -> up (mainline) | 0 | 176 MB/s |
| drive strength level 3 -> 2 (mainline) | 0 | 178 MB/s |

Fix: `&emmc_strb { rockchip,pins = <1 RK_PB2 1 &pcfg_pull_down>; };` in
`dts/rk3576s-wf2489t.dtsi`, back to HS400ES. Result with otherwise mainline
pins: 0 errors over 15 GiB written (`err_stats` all 0), 176 MB/s write,
290 MB/s read. The HS200 interim setting is no longer needed.

Sent upstream on 2026-11-09 as "[PATCH] arm64: dts: rockchip: Pull down the
eMMC data strobe on RK3576" (to Heiko Stuebner, Cc linux-rockchip, stable):
https://lore.kernel.org/linux-rockchip/?q=s%3A%22Pull+down+the+eMMC+data+strobe%22
Once it is merged, the `&emmc_strb` override in `dts/rk3576s-wf2489t.dtsi`
can go.

Never set a pull-up on GPIO1_B2 (strobe) or B3 (RSTN) at runtime: a pull-up on
the strobe caused real I/O errors and a read-only remount during these tests.
