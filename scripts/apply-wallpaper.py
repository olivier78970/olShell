#!/usr/bin/env python3
"""Show an image as the wallpaper with awww, starting its daemon first if needed.

  apply-wallpaper.py [awww img options...] IMAGE

awww draws nothing unless its daemon is running, and nothing starts it at login
here, so it is started (detached, with its output on /dev/null: it must outlive
this script and the shell that ran it, and must not write to a pipe that is
closed when they exit) when a query gets no answer. The options are passed to
`awww img` as they are (see `awww img --help`).
"""
import subprocess
import sys
import time

DAEMON_TIMEOUT = 5  # seconds to wait for a freshly started daemon


def daemon_up():
    return subprocess.run(
        ["awww", "query"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    ).returncode == 0


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    *options, image = sys.argv[1:]

    if not daemon_up():
        subprocess.Popen(
            ["awww-daemon"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        deadline = time.monotonic() + DAEMON_TIMEOUT
        while not daemon_up():
            if time.monotonic() > deadline:
                sys.exit("awww-daemon did not start")
            time.sleep(0.1)

    sys.exit(subprocess.run(["awww", "img", *options, image], stdin=subprocess.DEVNULL).returncode)


if __name__ == "__main__":
    main()
