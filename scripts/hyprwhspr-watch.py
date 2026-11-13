#!/usr/bin/env python3
"""Prints hyprwhspr's state whenever it changes.

Usage: hyprwhspr-watch.py

Asks systemd about the hyprwhspr.service user unit every second and reads the
signal files the daemon keeps in $XDG_RUNTIME_DIR/hyprwhspr (the same ones its
Waybar module reads) four times a second, and prints one JSON line at start
and after every change:
  {"service": "active", "recording": false, "processing": false, "unloaded": false}
`service` is systemd's ActiveState (active, activating, deactivating,
inactive, failed), or "missing" when the unit isn't installed. `recording` is
true while it records, `processing` while it transcribes (only known when its
mic-osd overlay is on), `unloaded` while its model was unloaded to free the
GPU (`hyprwhspr model unload`). Used by services/Hyprwhspr.qml.
"""
import json
import os
import subprocess
import tempfile
import time

UNIT = "hyprwhspr.service"
POLL = 0.25  # seconds between two looks at the signal files
SERVICE_EVERY = 4  # file looks between two questions to systemd

# The daemon's runtime directory (as its src/paths.py picks it).
if os.environ.get("XDG_RUNTIME_DIR"):
    RUNTIME = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hyprwhspr")
else:
    RUNTIME = os.path.join(tempfile.gettempdir(), f"hyprwhspr-{os.getuid()}")


def emit(state):
    print(json.dumps(state), flush=True)


def service():
    """The unit's ActiveState ("missing" without the unit) and when it last
    became active (Unix seconds, 0 if never)."""
    try:
        out = subprocess.run(
            ["systemctl", "--user", "show", UNIT, "-p", "LoadState", "-p", "ActiveState",
             "-p", "ActiveEnterTimestamp", "--timestamp=unix"],
            capture_output=True, text=True, timeout=2,
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return "missing", 0
    values = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    if values.get("LoadState") == "not-found":
        return "missing", 0
    started = values.get("ActiveEnterTimestamp", "").lstrip("@")
    return values.get("ActiveState", "inactive"), int(started) if started.isdigit() else 0


def read(name):
    try:
        with open(os.path.join(RUNTIME, name)) as f:
            return f.read().strip()
    except OSError:
        return None


def mtime(name):
    try:
        return os.stat(os.path.join(RUNTIME, name)).st_mtime
    except OSError:
        return None


last = None
tick = 0
active, started = service()
while True:
    if tick % SERVICE_EVERY == 0:
        active, started = service()
    tick += 1
    running = active == "active"
    # The daemon removes its files as it stops, but not after a crash, and it
    # never clears the unloaded marker on start: a marker older than the
    # running service is left over from before.
    unloaded_at = mtime("model_unloaded")
    state = {
        "service": active,
        "recording": running and read("recording_status") == "true",
        "processing": running and read("visualizer_state") == "processing",
        "unloaded": running and unloaded_at is not None and unloaded_at >= started,
    }
    if state != last:
        last = state
        emit(state)
    time.sleep(POLL)
