#!/usr/bin/env python3
"""Downloads Bing's picture of the day from bing.biturl.top and prints its path.

Usage: bing-picture.py <directory> [--index N] [--days N]
                       [--market MKT] [--resolution RES] [--notify TITLE BUTTON]

The picture is saved as <directory>/bing-<start date>.jpg (the directory is
created if needed), next to the service's answer (its description: the
copyright, a link) as bing-<start date>.json; an existing picture is not
downloaded again. With --notify, a newly downloaded picture is announced with
notify-send (when installed): TITLE, the description as its text and, with the
link, a button labelled BUTTON opening it in the browser (a detached process waits for the
click, so the script doesn't). --index picks an earlier day (0 is today, up to 7).
--days N also downloads the N-1 days before it (the service keeps about 8; a
failure there is ignored, and they are never announced).
--market the region (default en-US) and
--resolution one of UHD, 1920 or 1366 (default UHD). The last line printed on
success is the picture's path. Exits with 1, saying why on stderr, when the
service or the download fails.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request

API = "https://bing.biturl.top/"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "olShell"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def notify(title, path, info, button):
    """Announces a new picture with its description from the service."""
    if not shutil.which("notify-send"):
        return
    link = info.get("copyright_link", "")
    if not link or not shutil.which("xdg-open"):
        subprocess.run(["notify-send", "--icon", path, "--app-name", "olShell", title,
                        info.get("copyright", "")], check=False)
        return
    # With a button notify-send waits for the click, so it runs in a detached
    # process (this script is then called again, with --wait-click).
    subprocess.Popen([sys.executable, os.path.abspath(__file__), "--wait-click", link, button, path, title,
                      info.get("copyright", "")], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def wait_click(link, button, path, title, body):
    """Shows the notification with a button and opens the link when it is clicked."""
    answer = subprocess.run(["notify-send", "--icon", path, "--app-name", "olShell",
                             "--action=open=" + button, title, body],
                            capture_output=True, text=True, check=False)
    if answer.stdout.strip() == "open":
        subprocess.run(["xdg-open", link], check=False)


def save(args, index):
    """Saves the picture of a day and its description; returns the picture's
    path, the description and whether the picture was not there yet."""
    query = urllib.parse.urlencode({
        "format": "json",
        "index": index,
        "mkt": args.market,
        "resolution": args.resolution,
    })
    info = json.loads(fetch(API + "?" + query))
    os.makedirs(args.directory, exist_ok=True)
    path = os.path.join(args.directory, "bing-%s.jpg" % info["start_date"])
    fresh = not os.path.exists(path)
    if fresh:
        data = fetch(info["url"])
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
    with open(os.path.splitext(path)[0] + ".json", "w") as f:
        json.dump(info, f, ensure_ascii=False, indent=2)
    return path, info, fresh


def main():
    # The detached part of notify(): not a user-facing mode.
    if len(sys.argv) == 7 and sys.argv[1] == "--wait-click":
        wait_click(*sys.argv[2:])
        return 0
    parser = argparse.ArgumentParser()
    parser.add_argument("directory")
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--market", default="en-US")
    parser.add_argument("--resolution", default="UHD")
    parser.add_argument("--days", type=int, default=1)
    parser.add_argument("--notify", nargs=2, metavar=("TITLE", "BUTTON"))
    args = parser.parse_args()

    # The earlier days first (--days), failures there don't matter; then the
    # picture asked for, whose failure is the script's.
    for index in range(args.index + args.days - 1, args.index, -1):
        try:
            save(args, index)
        except (OSError, ValueError, KeyError):
            pass
    try:
        path, info, fresh = save(args, args.index)
    except (OSError, ValueError, KeyError) as error:
        print("bing-picture: %s" % error, file=sys.stderr)
        return 1

    if fresh and args.notify:
        notify(args.notify[0], path, info, args.notify[1])
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
