#!/usr/bin/env python3
"""Split a BL31 ELF into one binary per PT_LOAD segment, named bl31_0x<paddr>.bin.

Same result as Rockchip's U-Boot packing (arch/arm/mach-rockchip/make_fit_atf.sh),
which the FIT in u-boot.its references (atf-1/2/3 at their load addresses).

usage: split-bl31.py <bl31.elf> <out dir>
"""
import os
import struct
import sys

elf_path, out_dir = sys.argv[1:3]
data = open(elf_path, "rb").read()
assert data[:4] == b"\x7fELF" and data[4] == 2, "expects a 64-bit ELF"
e_phoff, = struct.unpack_from("<Q", data, 0x20)
e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)
os.makedirs(out_dir, exist_ok=True)
for i in range(e_phnum):
    p_type, _flags, p_offset, _vaddr, p_paddr, p_filesz, _memsz, _align = \
        struct.unpack_from("<IIQQQQQQ", data, e_phoff + i * e_phentsize)
    if p_type != 1 or p_filesz == 0:       # PT_LOAD with file contents only
        continue
    name = os.path.join(out_dir, "bl31_0x%08x.bin" % p_paddr)
    with open(name, "wb") as f:
        f.write(data[p_offset:p_offset + p_filesz])
    print("%s: %d bytes" % (name, p_filesz))
