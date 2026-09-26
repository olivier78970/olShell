#!/usr/bin/env python3
"""Prints the default browser's default search engine, as JSON.

Usage: default-search-engine.py

The default browser is the one `xdg-settings get default-web-browser` names.
Firefox and the browsers built on it (Zen, LibreWolf, Floorp, Waterfox) keep
their engines in their profile's search.json.mozlz4: the one it uses (the
profile the browser starts with, from profiles.ini) and its default engine
are read from there. An engine the user added has its address stored with
it; the built-in ones only have an id ("ddg", "google", "wikipedia-fr"...),
whose address is known here. Chromium-based browsers keep theirs in the
Default profile's Preferences (Google when it was never changed).

Prints {"name": NAME, "url": URL}, with %s in URL where the search goes, or
{"name": NAME, "url": null} for a built-in engine unknown here, or {} when
there is no default browser, or not one of these.
"""

import configparser
import json
import os
import struct
import subprocess
import sys
from urllib.parse import quote

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")

# The profile folders of the Firefox-based browsers, by a word of their
# desktop entry's name, in the order they are looked for.
FIREFOX_DIRS = {
    "zen": [os.path.join(CONFIG, "zen"), os.path.join(HOME, ".zen")],
    "librewolf": [os.path.join(CONFIG, "librewolf", "librewolf"), os.path.join(HOME, ".librewolf")],
    "floorp": [os.path.join(CONFIG, "floorp"), os.path.join(HOME, ".floorp")],
    "waterfox": [os.path.join(CONFIG, "waterfox"), os.path.join(HOME, ".waterfox")],
    "firefox": [os.path.join(CONFIG, "mozilla", "firefox"), os.path.join(HOME, ".mozilla", "firefox")],
}

# The profile folders of the Chromium-based browsers, the same way.
CHROMIUM_DIRS = {
    "brave": os.path.join(CONFIG, "BraveSoftware", "Brave-Browser"),
    "vivaldi": os.path.join(CONFIG, "vivaldi"),
    "google-chrome": os.path.join(CONFIG, "google-chrome"),
    "chromium": os.path.join(CONFIG, "chromium"),
}

# The addresses of Firefox's built-in engines, by id.
BUILT_IN = {
    "google": "https://www.google.com/search?q=%s",
    "ddg": "https://duckduckgo.com/?q=%s",
    "bing": "https://www.bing.com/search?q=%s",
    "qwant": "https://www.qwant.com/?q=%s",
    "startpage": "https://www.startpage.com/sp/search?query=%s",
    "ecosia": "https://www.ecosia.org/search?q=%s",
    "perplexity": "https://www.perplexity.ai/search?q=%s",
    "baidu": "https://www.baidu.com/s?wd=%s",
    "yandex": "https://yandex.com/search/?text=%s",
}

# eBay's domain for the country an "ebay-xx" id ends with, when it isn't
# ebay.xx.
EBAY_DOMAINS = {"uk": "co.uk", "au": "com.au", "us": "com"}


def mozlz4(path):
    """The contents of a Mozilla LZ4 file: a header, then one LZ4 block."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"mozLz40\0":
        raise ValueError("not a mozlz4 file")
    size = struct.unpack("<I", data[8:12])[0]
    src = data[12:]
    out = bytearray()
    i = 0
    while i < len(src):
        token = src[i]
        i += 1
        length = token >> 4
        if length == 15:
            while True:
                byte = src[i]
                i += 1
                length += byte
                if byte != 255:
                    break
        out += src[i:i + length]
        i += length
        # The last sequence is literals only.
        if i >= len(src):
            break
        offset = src[i] | src[i + 1] << 8
        i += 2
        length = token & 15
        if length == 15:
            while True:
                byte = src[i]
                i += 1
                length += byte
                if byte != 255:
                    break
        length += 4
        # Byte by byte: the match may overlap what it copies.
        for _ in range(length):
            out.append(out[-offset])
    return bytes(out[:size])


def firefox_profile(root):
    """The profile folder the browser under `root` starts with, or None."""
    ini = configparser.ConfigParser(interpolation=None)
    ini.optionxform = str
    if not ini.read(os.path.join(root, "profiles.ini")):
        return None
    # The install's own default comes first, as the browser does it.
    path = next((ini[s]["Default"] for s in ini.sections() if s.startswith("Install") and "Default" in ini[s]), None)
    if path is None:
        section = next((s for s in ini.sections() if s.startswith("Profile") and ini[s].get("Default") == "1"), None)
        if section is None:
            return None
        path = ini[section]["Path"]
        if ini[section].get("IsRelative", "1") == "0":
            return path
    return os.path.join(root, path)


def built_in_url(engine_id):
    """The address of a built-in engine, or None when it's unknown here."""
    if engine_id in BUILT_IN:
        return BUILT_IN[engine_id]
    if engine_id.startswith("wikipedia"):
        lang = engine_id.split("-", 1)[1] if "-" in engine_id else "en"
        return f"https://{lang}.wikipedia.org/wiki/Special:Search?search=%s"
    if engine_id.startswith("ebay"):
        country = engine_id.split("-", 1)[1] if "-" in engine_id else "us"
        return f"https://www.ebay.{EBAY_DOMAINS.get(country, country)}/sch/i.html?_nkw=%s"
    return None


def user_url(engine):
    """The address of an engine the user added (a GET one), or None."""
    for url in engine.get("_urls", []):
        if url.get("type", "text/html") != "text/html" or url.get("method", "GET") != "GET":
            continue
        template = url.get("template", "")
        params = [p for p in url.get("params", []) if "name" in p and "value" in p]
        if params:
            query = "&".join(quote(p["name"]) + "=" + p["value"] for p in params)
            template += ("&" if "?" in template else "?") + query
        if "{searchTerms}" in template:
            return template.replace("{searchTerms}", "%s")
    return None


def firefox(dirs):
    for root in dirs:
        profile = firefox_profile(root)
        if profile is None:
            continue
        store = json.loads(mozlz4(os.path.join(profile, "search.json.mozlz4")))
        meta = store.get("metaData", {})
        engine_id = meta.get("defaultEngineId") or meta.get("appDefaultEngineId") or ""
        engine = next((e for e in store.get("engines", []) if e.get("id") == engine_id), None)
        if engine is None:
            return {}
        return {"name": engine.get("_name", engine_id), "url": user_url(engine) or built_in_url(engine_id)}
    return {}


def chromium(root):
    try:
        with open(os.path.join(root, "Default", "Preferences")) as f:
            prefs = json.load(f)
    except OSError:
        return {}
    data = prefs.get("default_search_provider_data", {}).get("template_url_data")
    if not data or "{searchTerms}" not in data.get("url", ""):
        return {"name": "Google", "url": BUILT_IN["google"]}
    return {"name": data.get("short_name", ""), "url": data["url"].replace("{searchTerms}", "%s")}


def main():
    try:
        browser = subprocess.run(["xdg-settings", "get", "default-web-browser"],
                                 capture_output=True, text=True, timeout=5).stdout.strip().lower()
    except (OSError, subprocess.TimeoutExpired):
        browser = ""
    result = {}
    try:
        key = next((k for k in FIREFOX_DIRS if k in browser), None)
        if key:
            result = firefox(FIREFOX_DIRS[key])
        else:
            key = next((k for k in CHROMIUM_DIRS if k in browser), None)
            if key:
                result = chromium(CHROMIUM_DIRS[key])
    except (OSError, ValueError, KeyError, IndexError) as error:
        print(f"default-search-engine: {error}", file=sys.stderr)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
