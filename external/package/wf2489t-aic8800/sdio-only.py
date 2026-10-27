#!/usr/bin/env python3
"""Print only the src/SDIO file sections of a unified diff.

Radxa's Debian patches cover the SDIO, PCIe and USB variants of the driver;
only the SDIO one is built here, and some USB sources have CRLF line endings
that make the USB sections fail to apply.

usage: sdio-only.py <patch>
"""
import sys

lines = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read().split("\n")
out, keep, i = [], False, 0
while i < len(lines):
    line = lines[i]
    if line.startswith("diff "):
        keep = False
    elif line.startswith("--- ") and i + 1 < len(lines) and lines[i + 1].startswith("+++ "):
        keep = "/src/SDIO/" in lines[i + 1]
        if keep:
            out += [line, lines[i + 1]]
        i += 2
        continue
    if keep:
        out.append(line)
    i += 1
sys.stdout.write("\n".join(out) + ("\n" if out else ""))
