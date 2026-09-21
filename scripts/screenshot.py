#!/usr/bin/env python3
"""Takes a screenshot with grim, saves it, copies it to the clipboard and says so.

Usage: screenshot.py <screen|region|window> <directory> [notification title] [--edit]

  screen  the focused monitor
  region  a rectangle drawn with slurp
  window  a window picked with slurp among the ones on show (hyprctl)

The picture goes to <directory>/screenshot-<date>_<time>.png (the directory is
created if needed), is copied to the clipboard with wl-copy and announced with
notify-send, when those tools exist. Cancelling the selection (Escape) does
nothing. With --edit the picture is then opened in satty (when installed) to
annotate it: Enter there copies the result to the clipboard and saves it next
to the original as <name>-edited.png, and closes satty. Used by
services/Screenshot.qml.
"""
import json
import os
import shutil
import subprocess
import sys
import time


def run(command, **kwargs):
    return subprocess.run(command, capture_output=True, text=True, **kwargs)


def focused_monitor():
    monitors = json.loads(run(["hyprctl", "-j", "monitors"]).stdout)
    focused = next((m for m in monitors if m.get("focused")), monitors[0])
    return focused["name"]


def visible_windows():
    """One "x,y wxh" line per mapped window on a workspace shown on a monitor."""
    monitors = json.loads(run(["hyprctl", "-j", "monitors"]).stdout)
    shown = {m["activeWorkspace"]["id"] for m in monitors}
    shown |= {m["specialWorkspace"]["id"] for m in monitors if m.get("specialWorkspace", {}).get("id")}
    clients = json.loads(run(["hyprctl", "-j", "clients"]).stdout)
    return [
        "%d,%d %dx%d" % (c["at"][0], c["at"][1], c["size"][0], c["size"][1])
        for c in clients
        if c.get("mapped") and not c.get("hidden") and c["workspace"]["id"] in shown
    ]


def pick(mode):
    """The grim arguments for the area to capture, or None if cancelled."""
    if mode == "screen":
        return ["-o", focused_monitor()]
    if mode == "region":
        # No boxes to choose from: stdin must be empty, not left open (slurp
        # reads it to the end before it starts, and the shell's never ends).
        chosen = run(["slurp"], stdin=subprocess.DEVNULL)
    else:
        windows = visible_windows()
        if not windows:
            return None
        chosen = run(["slurp", "-r"], input="\n".join(windows))
    geometry = chosen.stdout.strip()
    return ["-g", geometry] if chosen.returncode == 0 and geometry else None


def annotate(path, directory):
    """Opens the picture in satty, on its own so the caller isn't kept waiting."""
    edited = os.path.join(directory, time.strftime("screenshot-%Y-%m-%d_%H-%M-%S-edited.png"))
    subprocess.Popen(
        ["satty", "--filename", path, "--output-filename", edited,
         "--copy-command", "wl-copy --type image/png", "--save-after-copy",
         "--actions-on-enter", "save-to-clipboard", "--early-exit", "all"],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def main():
    args = [arg for arg in sys.argv[1:] if arg != "--edit"]
    edit = "--edit" in sys.argv[1:]
    if len(args) < 2 or args[0] not in ("screen", "region", "window"):
        sys.exit("usage: screenshot.py <screen|region|window> <directory> [title] [--edit]")
    mode, directory = args[0], args[1]
    title = args[2] if len(args) > 2 else "Screenshot saved"

    area = pick(mode)
    if area is None:
        return
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, time.strftime("screenshot-%Y-%m-%d_%H-%M-%S.png"))
    if run(["grim"] + area + [path]).returncode != 0:
        sys.exit("grim failed")

    if shutil.which("wl-copy"):
        with open(path, "rb") as image:
            subprocess.run(["wl-copy", "--type", "image/png"], stdin=image)
    if edit and shutil.which("satty"):
        annotate(path, directory)
    elif shutil.which("notify-send"):
        run(["notify-send", "--icon", path, "--app-name", "olShell", title, path])


if __name__ == "__main__":
    main()
