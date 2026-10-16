#!/usr/bin/env python3
"""Set the font of GTK and Qt apps.

  app-fonts.py FAMILY MONO_FAMILY [--apps SIZE] [--alacritty SIZE] [--restore-apps]

FAMILY is the interface font, MONO_FAMILY the monospace one (GTK's
monospace-font-name, Qt's fixed font and the terminal's).
--apps sets the GTK and Qt apps' font (in points), --alacritty the terminal's.
--restore-apps gives the GTK and Qt apps their default font back: gsettings
reset for GTK, and the font keys removed from the qt5ct and qt6ct files.
GTK apps follow gsettings' org.gnome.desktop.interface font-name,
document-font-name and monospace-font-name (applied live). Qt apps read
the [Fonts] section of ~/.config/qt5ct/qt5ct.conf and qt6ct/qt6ct.conf, whose
other sections are left as they are; the file is created with only that
section when it doesn't exist. Running Qt apps re-read the file as it changes.
Alacritty gets ~/.config/alacritty/font.toml, a file its alacritty.toml imports
(and reloads while it runs), and the font is also sent to the running windows
with `alacritty msg config`, which works even when the file isn't imported (a
window that starts later reads the config file, not that message).
"""
import os
import argparse
import glob
import re
import subprocess
import sys
import time

HOME = os.path.expanduser("~")


def set_gtk(family, mono, size):
    fonts = {"font-name": family, "document-font-name": family, "monospace-font-name": mono}
    for key, name in fonts.items():
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, f"{name} {size}"],
                       check=False, stderr=subprocess.DEVNULL)


def reset_gtk():
    for key in ("font-name", "document-font-name", "monospace-font-name"):
        subprocess.run(["gsettings", "reset", "org.gnome.desktop.interface", key],
                       check=False, stderr=subprocess.DEVNULL)


def reset_qt(path):
    """Remove the font keys from [Fonts], and the section when nothing else is in it."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    out, in_fonts = [], False
    for line in lines:
        section = re.match(r"^\s*\[([^\]]+)\]", line)
        if section:
            in_fonts = section.group(1) == "Fonts"
        elif in_fonts and "=" in line and line.split("=", 1)[0].strip() in ("general", "fixed"):
            continue
        out.append(line)
    # Drop a [Fonts] header left with no key under it.
    cleaned = []
    for i, line in enumerate(out):
        if re.match(r"^\s*\[Fonts\]\s*$", line):
            rest = out[i + 1:]
            nxt = next((l for l in rest if l.strip()), None)
            if nxt is None or re.match(r"^\s*\[", nxt):
                continue
        cleaned.append(line)
    text = "\n".join(cleaned)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def qt_font(family, size, weight):
    # family, point size, pixel size (-1), style hint, weight, then the
    # italic, underline, strike-out and fixed-pitch flags and the raw mode.
    # Qt 5 rejects the longer Qt 6 form ("Invalid description"), so Qt 5's
    # weight (0-99) gets these ten fields and Qt 6's (100-900) the full set.
    fields = f"{family},{size},-1,5,{weight},0,0,0,0,0"
    if weight > 99:
        fields += ",0,0,0,0,0,1"
    return f'"{fields}"'


def set_qt(path, family, mono, size, weight):
    lines = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            lines = f.read().split("\n")
    wanted = {"general": qt_font(family, size, weight), "fixed": qt_font(mono, size, weight)}
    out, in_fonts, found = [], False, False
    for line in lines:
        section = re.match(r"^\s*\[([^\]]+)\]", line)
        if section:
            if in_fonts:
                out.extend(f"{k}={v}" for k, v in wanted.items())
                wanted = {}
            in_fonts = section.group(1) == "Fonts"
            found = found or in_fonts
        elif in_fonts:
            key = line.split("=", 1)[0].strip()
            if key in wanted and "=" in line:
                out.append(f"{key}={wanted.pop(key)}")
                continue
        out.append(line)
    if in_fonts:
        out.extend(f"{k}={v}" for k, v in wanted.items())
    elif not found:
        while out and out[-1] == "":
            out.pop()
        out += ["[Fonts]"] + [f"{k}={v}" for k, v in wanted.items()]
    text = "\n".join(out)
    if not text.endswith("\n"):
        text += "\n"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def set_alacritty(family, size):
    path = os.path.join(HOME, ".config/alacritty/font.toml")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    escaped = family.replace("\\", "\\\\").replace('"', '\\"')
    with open(path, "w", encoding="utf-8") as f:
        f.write(f'[font]\nnormal.family = "{escaped}"\nsize = {size}\n')


def send_alacritty(family, size):
    """Set the font of every running alacritty window through its IPC sockets."""
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sockets = glob.glob(os.path.join(runtime, "Alacritty-*.sock"))
    if not sockets:
        return
    # A reload of the config file drops what `msg config` set, and writing
    # font.toml causes one in a window that imports it: let it happen first.
    time.sleep(1)
    escaped = family.replace("\\", "\\\\").replace('"', '\\"')
    for sock in sockets:
        subprocess.run(["alacritty", "msg", "--socket", sock, "config",
                        f'font.normal.family="{escaped}"', f"font.size={size}"],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("family")
    parser.add_argument("mono")
    parser.add_argument("--apps", type=int)
    parser.add_argument("--alacritty", type=int)
    parser.add_argument("--restore-apps", action="store_true")
    args = parser.parse_args()
    if args.apps is not None:
        # Qt 5 stores the weight on a 0-99 scale (50 is normal), Qt 6 on 100-900.
        set_gtk(args.family, args.mono, args.apps)
        set_qt(os.path.join(HOME, ".config/qt5ct/qt5ct.conf"), args.family, args.mono, args.apps, 50)
        set_qt(os.path.join(HOME, ".config/qt6ct/qt6ct.conf"), args.family, args.mono, args.apps, 400)
    elif args.restore_apps:
        reset_gtk()
        reset_qt(os.path.join(HOME, ".config/qt5ct/qt5ct.conf"))
        reset_qt(os.path.join(HOME, ".config/qt6ct/qt6ct.conf"))
    if args.alacritty is not None:
        set_alacritty(args.mono, args.alacritty)
        send_alacritty(args.mono, args.alacritty)


if __name__ == "__main__":
    main()
