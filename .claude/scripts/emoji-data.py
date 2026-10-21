#!/usr/bin/env python3
"""Writes modules/Emoji/emoji.<language>.tsv, the emoji panel's lists, one per
language of the shell: every fully-qualified emoji of Unicode's emoji-test.txt
but the skin-tone variants and the components, in Unicode's order, one per
line as `group<TAB>emoji<TAB>name<TAB>keywords`, the name and keywords (comma
separated) in that language from CLDR's annotations (the English ones for an
emoji it doesn't translate). Downloads both, so it needs the network.

Usage (from the repo root):
  .claude/scripts/emoji-data.py
Pick an emoji version the installed emoji font draws (Noto Color Emoji 2.05x:
16.0), with the CLDR release that goes with it (46 for 16.0).
"""
import json
import re
import urllib.request

EMOJI_VERSION = "16.0"
CLDR_VERSION = "46.0.0"
# The shell's languages (config/I18n.qml's `supported`).
LANGUAGES = ["en", "fr", "es"]
OUT = "modules/Emoji/emoji.{}.tsv"
TEST_URL = f"https://unicode.org/Public/emoji/{EMOJI_VERSION}/emoji-test.txt"
CLDR_URLS = [
    "https://cdn.jsdelivr.net/npm/cldr-annotations-full@{version}/annotations/{language}/annotations.json",
    "https://cdn.jsdelivr.net/npm/cldr-annotations-derived-full@{version}/annotationsDerived/{language}/annotations.json",
]
# Unicode's group names, by the ids the panel uses (EmojiPanel.qml's groups).
GROUPS = {
    "Smileys & Emotion": "smileys", "People & Body": "people", "Animals & Nature": "animals",
    "Food & Drink": "food", "Travel & Places": "travel", "Activities": "activities",
    "Objects": "objects", "Symbols": "symbols", "Flags": "flags",
}
SKIN_TONES = {0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF}
LINE = re.compile(r"^([0-9A-F ]+?)\s*; fully-qualified\s*# (\S+) E[\d.]+ (.+)$")


def fetch(url):
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8")


def emoji_list():
    """[(group, emoji, English name)] from emoji-test.txt."""
    group, rows = None, []
    for line in fetch(TEST_URL).split("\n"):
        if line.startswith("# group:"):
            group = GROUPS.get(line.split(":", 1)[1].strip())
            continue
        match = LINE.match(line)
        if not match or not group:
            continue
        if SKIN_TONES & {int(code, 16) for code in match.group(1).split()}:
            continue
        rows.append((group, match.group(2), match.group(3)))
    return rows


def annotations(language):
    """Each emoji's { tts: [name], default: [keywords] } in `language`."""
    found = {}
    for url in CLDR_URLS:
        data = json.loads(fetch(url.format(version=CLDR_VERSION, language=language)))
        found.update(next(iter(data.values()))["annotations"])
    return found


def clean(text):
    """`text` on one line, without the tabs and commas the file uses."""
    return " ".join(text.replace("\t", " ").replace(",", " ").split())


def main():
    rows = emoji_list()
    english = annotations("en")
    for language in LANGUAGES:
        local = annotations(language)
        lines = []
        for group, emoji, name in rows:
            entry = local.get(emoji) or local.get(emoji.replace("️", "")) \
                or english.get(emoji) or english.get(emoji.replace("️", "")) or {}
            title = clean(entry.get("tts", [name])[0])
            keywords = ",".join(clean(word) for word in entry.get("default", []))
            lines.append(f"{group}\t{emoji}\t{title}\t{keywords}")
        path = OUT.format(language)
        with open(path, "w", encoding="utf-8") as out:
            out.write(f"# The emoji the emoji panel shows in {language} (EmojiPanel.qml), one per line as\n")
            out.write("# group, emoji, name and keywords, tab-separated; from Unicode's emoji-test.txt\n")
            out.write(f"# {EMOJI_VERSION} and CLDR {CLDR_VERSION}, written by .claude/scripts/emoji-data.py.\n")
            out.write("\n".join(lines) + "\n")
        print(f"{path}: {len(lines)} emoji")


main()
