#!/usr/bin/env python3
"""Adds a text to the three dictionaries of config/Translations.qml (en, fr, es)
in one go, then checks them. Run from the repo root.

  add-translation.py KEY EN FR ES [--after OTHER.KEY]
  add-translation.py --rename OLD.KEY NEW.KEY

The new line goes after OTHER.KEY's line in each dictionary (keeping related
texts together), or at the end of the dictionary without --after. A key that
already exists is refused. {0}, {1}... stay as they are: use the same ones in
all three texts. --rename changes a key everywhere in the file, for when a key's
name no longer says what it is."""
import re
import subprocess
import sys
from pathlib import Path

TRANSLATIONS = Path("config/Translations.qml")
LANGUAGES = ["en", "fr", "es"]


def quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def block(lines, language):
    """The line numbers (start, end) of a language's dictionary: the line
    opening it and the one closing it."""
    start = next(i for i, line in enumerate(lines) if re.match(rf"^\s*readonly property var {language}: \(\{{", line))
    end = next(i for i in range(start + 1, len(lines)) if re.match(r"^  \}\)", lines[i]))
    return start, end


def add(key, texts, after):
    lines = TRANSLATIONS.read_text().split("\n")
    # Bottom dictionary first, so the line numbers of the others stay right.
    for language, text in reversed(list(zip(LANGUAGES, texts))):
        start, end = block(lines, language)
        if any(re.match(rf'^\s*{re.escape(quote(key))}:', line) for line in lines[start:end]):
            sys.exit(f"{key} already exists in {language}")
        new = f"    {quote(key)}: {quote(text)}"
        if after:
            index = next((i for i in range(start, end) if re.match(rf'^\s*{re.escape(quote(after))}:', lines[i])), None)
            if index is None:
                sys.exit(f"{after} not found in {language}")
            # Past a value spread over several lines (a count's one / other).
            while index + 1 < end and not re.match(r'^    ("|//)', lines[index + 1]):
                index += 1
            if lines[index].rstrip().endswith(","):
                lines.insert(index + 1, new + ",")
            else:
                # It was the last entry: it gets a comma, the new one none.
                lines[index] = lines[index].rstrip() + ","
                lines.insert(index + 1, new)
        else:
            # The last entry has no comma: give it one, and the new one none.
            last = end - 1
            while not lines[last].strip():
                last -= 1
            lines[last] = lines[last].rstrip().rstrip(",") + ","
            lines.insert(last + 1, new)
    TRANSLATIONS.write_text("\n".join(lines))


def rename(old, new):
    text = TRANSLATIONS.read_text()
    count = text.count(quote(old) + ":")
    if count != 3:
        sys.exit(f"{old} is in {count} dictionaries, not 3")
    TRANSLATIONS.write_text(text.replace(quote(old) + ":", quote(new) + ":"))
    print(f"renamed {old} to {new}; literal uses elsewhere (grep -rn '\"{old}\"') need the new name too")


def main():
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "--rename":
        rename(args[1], args[2])
    else:
        after = None
        if "--after" in args:
            i = args.index("--after")
            after = args[i + 1]
            del args[i:i + 2]
        if len(args) != 4:
            sys.exit(__doc__)
        add(args[0], args[1:], after)
    subprocess.run([sys.executable, ".claude/scripts/check-translations.py"])


main()
