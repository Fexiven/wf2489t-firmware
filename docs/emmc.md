# eMMC on the WF2489T (RK3576): HS400ES in Linux and U-Boot

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
Not yet compared: HS200, and stock Android on the same unit.

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
