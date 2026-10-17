#!/usr/bin/env python3
"""Says what each connected monitor can do, read from its EDID.

Usage: monitor-caps.py

Prints a JSON object, by connector name (the names Hyprland gives, "DP-1",
"HDMI-A-1"), of { "bits": the most bits per color the monitor declares (8 when
it says nothing), "hdr": whether it declares HDR static metadata }. The EDIDs
are read from /sys/class/drm, so nothing here talks to the monitors.
"""
import glob
import json
import os

# EDID 1.4 byte 0x14, bits 6-4: the bits per color of a digital monitor.
DEPTHS = {1: 6, 2: 8, 3: 10, 4: 12, 5: 14, 6: 16}


def capabilities(edid):
    bits = 8
    hdr = False
    if len(edid) >= 128 and edid[0x14] & 0x80:
        bits = max(bits, DEPTHS.get((edid[0x14] >> 4) & 7, 8))
    for start in range(128, len(edid) - 127, 128):
        block = edid[start:start + 128]
        # A CTA-861 extension: data blocks run from byte 4 to the detailed
        # timings' offset (byte 2).
        if block[0] != 0x02:
            continue
        end = min(block[2], 127)
        i = 4
        while i < end:
            tag, length = block[i] >> 5, block[i] & 0x1F
            data = block[i + 1:i + 1 + length]
            if tag == 7 and data and data[0] == 6:
                hdr = True
            # The HDMI vendor block (OUI 00-0C-03): byte 5 holds the deep
            # color flags, 30-bit (0x10) and 36-bit (0x20).
            if tag == 3 and length >= 6 and data[:3] == bytes([0x03, 0x0C, 0x00]):
                if data[5] & 0x20:
                    bits = max(bits, 12)
                elif data[5] & 0x10:
                    bits = max(bits, 10)
            i += 1 + length
    return {"bits": bits, "hdr": hdr}


def main():
    result = {}
    for path in glob.glob("/sys/class/drm/card*-*/edid"):
        connector = os.path.basename(os.path.dirname(path)).split("-", 1)[1]
        try:
            with open(path, "rb") as file:
                edid = file.read()
        except OSError:
            continue
        if edid:
            result[connector] = capabilities(edid)
    print(json.dumps(result))


main()
