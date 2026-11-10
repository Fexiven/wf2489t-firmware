# NPU (rocket, RK3576)

Temporary: these patches go away once RK3576 support for the `rocket` accel
driver is merged upstream. `kernel/build.sh` applies them after
`kernel/patches/*.patch`, `v16/` first.

| Directory | Source |
| --- | --- |
| `v16/` | Jiaxing Hu's RK3576 NPU series v16, patches 0001-0015 ([github.com/gahingwoo/linux-rk3576-npu](https://github.com/gahingwoo/linux-rk3576-npu), `rfc-send-v16/`, posted 2026-11-08). 0016 (enables the NPU on the ROCK 4D) is left out; the NPU nodes for this board are in `dts/rk3576s-wf2489t.dts`. |
| `rk3576-npu-open/` | 0001-0011 from [rk3576-npu-open](https://github.com/Fexiven/rk3576-npu-open) (`kernel/`): timeout recovery, both cores, lower latency, PPU tasks, devfreq with the PVTPLL clock. Descriptions there. |

The patches are unchanged copies; update them from those repositories.
