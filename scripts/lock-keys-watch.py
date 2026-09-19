#!/usr/bin/env python3
"""Prints the Caps Lock / Num Lock state whenever it changes.

Usage: lock-keys-watch.py

Reads the keyboards' lock LEDs in /sys/class/leds (`*::capslock`, `*::numlock`),
which the kernel keeps in sync with the lock state, and prints one line
"<caps> <num>" (each 0 or 1) at start and after every change. A lock counts as
on when any keyboard's LED is on. The LEDs are looked up again every couple of
seconds so a keyboard plugged in later is picked up. Used by services/LockKeys.qml.
"""
import glob
import os
import time

POLL = 0.1  # seconds between two reads
RESCAN = 20  # polls between two directory scans


def read(path):
    try:
        with open(path) as file:
            return int(file.read().strip()) > 0
    except (OSError, ValueError):
        return False


last = None
polls = 0
caps_leds = num_leds = []
while True:
    if polls % RESCAN == 0:
        caps_leds = glob.glob("/sys/class/leds/*::capslock/brightness")
        num_leds = glob.glob("/sys/class/leds/*::numlock/brightness")
    polls += 1
    state = (int(any(map(read, caps_leds))), int(any(map(read, num_leds))))
    if state != last:
        last = state
        print("%d %d" % state, flush=True)
    time.sleep(POLL)
