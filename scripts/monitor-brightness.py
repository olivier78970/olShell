#!/usr/bin/env python3
"""Reads and sets the brightness of the monitors.

Usage:
  monitor-brightness.py list
  monitor-brightness.py set ddc <bus number> <percent>
  monitor-brightness.py set backlight <device> <percent>

`set` exits with a failure status when the brightness wasn't taken.

`list` prints a JSON object, by connector name ("DP-1", "HDMI-A-1", "eDP-1"),
of { "kind": "ddc" or "backlight", "target": the I2C bus number or the
backlight device, "percent": the brightness now }. External monitors are
controlled over DDC/CI with ddcutil (it needs the i2c-dev module and a user
allowed to open /dev/i2c-*), a laptop's own screen through its backlight
device with brightnessctl. Monitors that offer neither are left out.
"""
import glob
import json
import os
import re
import subprocess
import sys


def run(command):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def ddc_monitors():
    """The monitors ddcutil can talk to, { connector: bus number }."""
    found = {}
    bus = None
    for line in run(["ddcutil", "detect", "--brief"]).splitlines():
        match = re.match(r"\s*I2C bus:\s+/dev/i2c-(\d+)", line)
        if match:
            bus = match.group(1)
        match = re.match(r"\s*DRM[_ ]connector:\s+card\d+-(\S+)", line)
        if match and bus is not None:
            found[match.group(1)] = bus
    return found


def ddc_percent(bus):
    # "VCP 10 C 40 100": the current value, then the maximum.
    match = re.search(r"VCP 10 C (\d+) (\d+)", run(["ddcutil", "getvcp", "10", "--brief", "--bus", bus]))
    if not match or int(match.group(2)) == 0:
        return None
    return round(100 * int(match.group(1)) / int(match.group(2)))


def listing():
    result = {}
    for connector, bus in ddc_monitors().items():
        percent = ddc_percent(bus)
        if percent is not None:
            result[connector] = {"kind": "ddc", "target": bus, "percent": percent}
    # A laptop's backlight belongs to its built-in screen (eDP, LVDS or DSI).
    internal = [os.path.basename(os.path.dirname(path)).split("-", 1)[1]
                for path in glob.glob("/sys/class/drm/card*-*/edid")
                if re.search(r"-(eDP|LVDS|DSI)-", path)]
    for device in sorted(glob.glob("/sys/class/backlight/*")):
        if not internal:
            break
        try:
            with open(device + "/brightness") as file:
                now = int(file.read())
            with open(device + "/max_brightness") as file:
                top = int(file.read())
        except (OSError, ValueError):
            continue
        if top > 0 and internal[0] not in result:
            result[internal[0]] = {"kind": "backlight", "target": os.path.basename(device), "percent": round(100 * now / top)}
    print(json.dumps(result))


def main():
    args = sys.argv[1:]
    if args == ["list"]:
        listing()
    elif len(args) == 4 and args[0] == "set" and args[1] in ("ddc", "backlight") and args[3].isdigit():
        percent = max(0, min(100, int(args[3])))
        if args[1] == "ddc" and args[2].isdigit():
            # Verified (ddcutil reads the value back), since some monitors take
            # the command and ignore it: the exit status says so.
            sys.exit(subprocess.run(["ddcutil", "setvcp", "10", str(percent), "--bus", args[2]], capture_output=True, timeout=20).returncode)
        elif args[1] == "backlight" and re.fullmatch(r"[\w.:-]+", args[2]):
            sys.exit(subprocess.run(["brightnessctl", "--device", args[2], "set", str(percent) + "%"], capture_output=True, timeout=20).returncode)
    else:
        sys.exit(__doc__)


main()
