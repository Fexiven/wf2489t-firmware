#!/usr/bin/env python3
"""Boot a Rockchip SoC in maskrom mode from RAM: upload DDR init (0x471) then SPL+payload (0x472).

usage: rk_maskrom_boot.py <u-boot-rockchip-usb471.bin> <u-boot-rockchip-usb472.bin> [--rc4]
Nothing is written to flash. Protocol as in rkdeveloptool/xrock: vendor control OUT
(bmRequestType 0x40, bRequest 0x0C, wIndex 0x471/0x472) in 4096-byte chunks, CRC16-CCITT
(init 0xFFFF) appended big-endian. RK35xx boot ROMs take the data without RC4 by default.
"""
import sys, time
import usb.core

RC4_KEY = bytes([124, 78, 3, 4, 85, 5, 9, 7, 45, 44, 123, 56, 23, 13, 23, 17])


def crc16_ccitt(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc


def rc4(data):
    s, j, out = list(range(256)), 0, bytearray()
    for i in range(256):
        j = (j + s[i] + RC4_KEY[i % len(RC4_KEY)]) & 0xFF
        s[i], s[j] = s[j], s[i]
    i = j = 0
    for b in data:
        i = (i + 1) & 0xFF; j = (j + s[i]) & 0xFF
        s[i], s[j] = s[j], s[i]
        out.append(b ^ s[(s[i] + s[j]) & 0xFF])
    return bytes(out)


def upload(dev, code, data, use_rc4):
    if use_rc4:   # rkdeveloptool encrypts per 512-byte block
        data = b"".join(rc4(data[i:i + 512]) for i in range(0, len(data), 512))
    crc = crc16_ccitt(data)
    data += bytes([crc >> 8, crc & 0xFF])
    for i in range(0, len(data), 4096):
        dev.ctrl_transfer(0x40, 0x0C, 0, code, data[i:i + 4096], timeout=5000)
    if len(data) % 4096 == 0:
        dev.ctrl_transfer(0x40, 0x0C, 0, code, b"\x00", timeout=5000)
    print(f"sent 0x{code:x}: {len(data)} bytes")


dev = usb.core.find(idVendor=0x2207)
if dev is None:
    sys.exit("no Rockchip USB device found")
mode = "maskrom" if (dev.bcdUSB & 1) == 0 else "loader"
print(f"found 2207:{dev.idProduct:04x} bcdUSB=0x{dev.bcdUSB:x} -> {mode}")
if mode != "maskrom":
    sys.exit("device is not in maskrom mode; refusing to send boot images")
use_rc4 = "--rc4" in sys.argv
upload(dev, 0x471, open(sys.argv[1], "rb").read(), use_rc4)
time.sleep(1.5)                 # let DDR init finish
upload(dev, 0x472, open(sys.argv[2], "rb").read(), use_rc4)
print("done - SPL should now load U-Boot and boot from eMMC")
