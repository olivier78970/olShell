#!/usr/bin/env python3
"""Checks config/Translations.qml: every language has the same keys as English,
with the same {0}/{1} placeholders, and every literal I18n.tr("key") used in
the QML exists in English. Run from the repo root; exits 1 on any problem."""
import re
import sys
from pathlib import Path

TRANSLATIONS = Path("config/Translations.qml")
KEY = re.compile(r'^\s*"([^"]+)":\s*(.*)$')


def dictionaries(text):
    """{language: {key: value text}} for each `readonly property var xx: ({ ... })` block."""
    result, lang, key = {}, None, None
    for line in text.splitlines():
        start = re.match(r"^\s*readonly property var (\w+): \(\{", line)
        if start:
            lang, key = start.group(1), None
            result[lang] = {}
            continue
        if lang is None:
            continue
        if re.match(r"^\s*\}\)", line) and not line.startswith("      "):
            lang = None
            continue
        match = KEY.match(line)
        if match:
            key = match.group(1)
            result[lang][key] = match.group(2)
        elif key:
            # A value spread over several lines (a count's `one` / `other`).
            result[lang][key] += " " + line.strip()
    return result


def placeholders(value):
    return sorted(set(re.findall(r"\{\d+\}", value)))


def main():
    dicts = dictionaries(TRANSLATIONS.read_text())
    if "en" not in dicts:
        sys.exit("No `en` dictionary found in config/Translations.qml")
    en = dicts["en"]
    problems = 0
    for lang, entries in dicts.items():
        if lang == "en":
            continue
        missing = [k for k in en if k not in entries]
        extra = [k for k in entries if k not in en]
        mismatched = [k for k in en if k in entries and placeholders(en[k]) != placeholders(entries[k])]
        for label, keys in (("missing", missing), ("not in en", extra), ("placeholders differ", mismatched)):
            for k in keys:
                print(f"{lang}: {label}: {k}")
            problems += len(keys)

    # Literal keys passed to I18n.tr() anywhere in the QML (keys built at run
    # time, like "settings.widget." + id, can't be checked here).
    used = {}
    for path in Path(".").rglob("*.qml"):
        if ".claude" in path.parts:
            continue
        for number, line in enumerate(path.read_text().splitlines(), 1):
            # A key followed by `+` is only the start of one built at run time.
            for key in re.findall(r'I18n\.tr\("([^"]+)"(?!\s*\+)', line):
                used.setdefault(key, f"{path}:{number}")
    for key, where in sorted(used.items()):
        if key not in en:
            print(f"used but not in en: {key} ({where})")
            problems += 1

    counts = ", ".join(f"{lang} {len(entries)}" for lang, entries in dicts.items())
    print(f"{counts} keys; {len(used)} literal keys used; {problems} problem(s)")
    sys.exit(1 if problems else 0)


main()
