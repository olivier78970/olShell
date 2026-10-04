#!/usr/bin/env python3
"""Finds the icons of web sites and keeps them in a folder, for the web apps.

Usage: favicon.py CACHE_DIR URL...

For each URL, the icon is looked for in the page's <link rel="icon">,
"shortcut icon" and "apple-touch-icon" tags (the largest one, by its `sizes`,
an SVG counting as the largest), then at /favicon.ico. It is saved in CACHE_DIR
as one file per site (its host), and an icon already there is used without
going to the network. An .ico is turned into a PNG of its largest image when
Pillow is installed.

Prints {URL: PATH} as JSON, with "" for a site whose icon wasn't found.
"""

import io
import json
import os
import re
import sys
import urllib.request
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse

TIMEOUT = 8
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
# The file name endings, by the type the server gives or the address ends with.
EXTENSIONS = {"image/png": "png", "image/svg+xml": "svg", "image/x-icon": "ico", "image/vnd.microsoft.icon": "ico",
              "image/jpeg": "jpg", "image/gif": "gif", "image/webp": "webp"}


class IconLinks(HTMLParser):
    """Collects the page's icon links as (address, size), size 0 if not given."""

    def __init__(self):
        super().__init__()
        self.icons = []

    def handle_starttag(self, tag, attrs):
        if tag != "link":
            return
        attrs = dict(attrs)
        rel = (attrs.get("rel") or "").lower().split()
        href = attrs.get("href")
        if not href or not ("icon" in rel or "apple-touch-icon" in rel):
            return
        size = 0
        sizes = (attrs.get("sizes") or "").lower()
        if sizes == "any" or href.lower().split("?")[0].endswith(".svg") or attrs.get("type") == "image/svg+xml":
            size = 10000
        else:
            found = [int(match) for match in re.findall(r"(\d+)x\d+", sizes)]
            if found:
                size = max(found)
            elif "apple-touch-icon" in rel:
                size = 180
        self.icons.append((href, size))


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return response.geturl(), response.headers.get_content_type(), response.read(2_000_000)


def extension(content_type, url, data):
    if data.lstrip()[:5] in (b"<?xml", b"<svg ") or b"<svg" in data[:300]:
        return "svg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if data[:4] == b"\x00\x00\x01\x00":
        return "ico"
    if content_type in EXTENSIONS:
        return EXTENSIONS[content_type]
    ending = urlparse(url).path.rsplit(".", 1)[-1].lower()
    return ending if ending in EXTENSIONS.values() else None


def to_png(data):
    """The largest image of an .ico as a PNG, or None without Pillow."""
    try:
        from PIL import Image
    except ImportError:
        return None
    try:
        image = Image.open(io.BytesIO(data))
        sizes = image.info.get("sizes")
        if sizes:
            image.size = max(sizes)
        out = io.BytesIO()
        image.save(out, "PNG")
        return out.getvalue()
    except Exception:
        return None


def candidates(url):
    """The icon addresses to try, best first."""
    found = []
    try:
        page_url, content_type, data = fetch(url)
        if content_type in ("text/html", "application/xhtml+xml"):
            parser = IconLinks()
            parser.feed(data.decode("utf-8", "replace"))
            found = [urljoin(page_url, href) for href, size in sorted(parser.icons, key=lambda icon: -icon[1])]
    except Exception:
        page_url = url
    parts = urlparse(page_url)
    found.append(f"{parts.scheme}://{parts.netloc}/favicon.ico")
    return found


def icon_for(url, cache_dir):
    host = urlparse(url).netloc.lower()
    if not host:
        return ""
    name = re.sub(r"[^a-z0-9.-]", "_", host)
    for existing in os.listdir(cache_dir):
        if existing.rsplit(".", 1)[0] == name:
            return os.path.join(cache_dir, existing)
    for icon_url in candidates(url):
        try:
            final_url, content_type, data = fetch(icon_url)
        except Exception:
            continue
        ext = extension(content_type, final_url, data) if data else None
        if ext is None:
            continue
        if ext == "ico":
            png = to_png(data)
            if png:
                data, ext = png, "png"
        path = os.path.join(cache_dir, f"{name}.{ext}")
        with open(path + ".part", "wb") as file:
            file.write(data)
        os.replace(path + ".part", path)
        return path
    return ""


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    cache_dir = sys.argv[1]
    os.makedirs(cache_dir, exist_ok=True)
    print(json.dumps({url: icon_for(url, cache_dir) for url in sys.argv[2:]}))


if __name__ == "__main__":
    main()
