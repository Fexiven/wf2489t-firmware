#!/usr/bin/env python3
"""Write the FIT source for the stock Rockchip SPL: TF-A BL31 + U-Boot + DTB.

Splits the BL31 ELF into one binary per PT_LOAD segment (bl31_0x<addr>.bin,
like Rockchip's make_fit_atf.sh) and writes u-boot.its next to them. The
segment holding the ELF entry point becomes "atf-1", the SPL's "firmware";
the others and U-Boot are "loadables". No BL32/OP-TEE.

usage: make-fit-its.py <bl31.elf> <out dir> <u-boot load address>
"""
import os
import struct
import sys

elf_path, out_dir, uboot_load = sys.argv[1], sys.argv[2], int(sys.argv[3], 0)
data = open(elf_path, "rb").read()
assert data[:4] == b"\x7fELF" and data[4] == 2, "expects a 64-bit ELF"
e_entry, e_phoff = struct.unpack_from("<QQ", data, 0x18)
e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)

segments = []
for i in range(e_phnum):
    p_type, _flags, p_offset, _vaddr, p_paddr, p_filesz, _memsz, _align = \
        struct.unpack_from("<IIQQQQQQ", data, e_phoff + i * e_phentsize)
    if p_type != 1 or p_filesz == 0:       # PT_LOAD with file contents only
        continue
    name = "bl31_0x%08x.bin" % p_paddr
    with open(os.path.join(out_dir, name), "wb") as f:
        f.write(data[p_offset:p_offset + p_filesz])
    segments.append((p_paddr, p_filesz, name))
segments.sort(key=lambda s: not (s[0] <= e_entry < s[0] + s[1]))   # entry first
assert segments[0][0] <= e_entry < segments[0][0] + segments[0][1], "no segment holds the entry point"


def image(node, desc, data, typ, os_, load):
    load = "\t\t\tload = /bits/ 64 <0x%x>;\n" % load if load is not None else ""
    os_ = "\t\t\tos = \"%s\";\n" % os_ if os_ else ""
    return (f"\t\t{node} {{\n\t\t\tdescription = \"{desc}\";\n\t\t\tdata = /incbin/(\"{data}\");\n"
            f"\t\t\ttype = \"{typ}\";\n\t\t\tarch = \"arm64\";\n{os_}\t\t\tcompression = \"none\";\n{load}"
            f"\t\t\thash {{\n\t\t\t\talgo = \"sha256\";\n\t\t\t}};\n\t\t}};\n")


atf = ["atf-%d" % (i + 1) for i in range(len(segments))]
its = "/dts-v1/;\n\n/ {\n\tdescription = \"WF2489T: TF-A BL31 + U-Boot\";\n\t#address-cells = <1>;\n\n\timages {\n"
its += image("uboot", "U-Boot", "u-boot-nodtb.bin", "standalone", "U-Boot", uboot_load)
for node, (addr, _size, name) in zip(atf, segments):
    its += image(node, "TF-A BL31", name, "firmware", "arm-trusted-firmware", addr)
its += image("fdt", "U-Boot dtb", "u-boot.dtb", "flat_dt", None, None)
its += ("\t};\n\n\tconfigurations {\n\t\tdefault = \"conf\";\n\t\tconf {\n\t\t\tdescription = \"wf2489t\";\n"
        f"\t\t\tfirmware = \"atf-1\";\n\t\t\tloadables = {', '.join(chr(34) + n + chr(34) for n in ['uboot'] + atf[1:])};\n"
        "\t\t\tfdt = \"fdt\";\n\t\t};\n\t};\n};\n")
open(os.path.join(out_dir, "u-boot.its"), "w").write(its)
for addr, size, name in segments:
    print("%s: %d bytes" % (name, size))
