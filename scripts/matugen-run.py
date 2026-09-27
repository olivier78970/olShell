#!/usr/bin/env python3
"""Run matugen with only the templates of the apps that are turned on.

  matugen-run.py CONFIG APPS ADDED [matugen options...]

CONFIG is the full matugen config (matugen/quickshell.toml) and APPS the apps
to theme, separated by commas (any of hyprland, zen, alacritty, gtk,
starship; empty for none). ADDED is a JSON list of apps added in the
settings, each {"name", "template", "output", "hook"}: the template file,
the file matugen writes from it and a shell command run after ("" for
none). A copy of CONFIG without the templates of the other apps, and with
the added apps' ones, is written next to it (so its relative template paths
still resolve), and matugen is then run in this script's place with that
copy as its config and the other options as they are.

A template belongs to an app by the start of its name ([templates.zengmail] is
Zen's, [templates.gtk4theme] GTK's); the shell's own palette and any template
that belongs to none of the apps are always kept. An added app without a
template or an output, or whose template can't be read, is left out (with a
line on stderr) rather than making the whole run fail.
"""
import json
import os
import re
import sys

APPS = ["hyprland", "zen", "alacritty", "gtk", "starship"]
SECTION = re.compile(r"^\s*\[([^\]]+)\]")


def app_of(section):
    """The app a [section] of the config belongs to, or None."""
    if not section.startswith("templates."):
        return None
    name = section[len("templates."):]
    return next((app for app in APPS if name.startswith(app)), None)


def filtered(text, apps):
    """`text` without the sections of the apps not in `apps`."""
    kept = []
    keep = True
    for line in text.splitlines(keepends=True):
        match = SECTION.match(line)
        if match:
            app = app_of(match.group(1).strip())
            keep = app is None or app in apps
        if keep:
            kept.append(line)
    return "".join(kept)


def added_sections(added):
    """The [templates.*] sections of the added apps that can be run."""
    sections = []
    for number, app in enumerate(added):
        name = app.get("name", "")
        template = os.path.expanduser(app.get("template", ""))
        output = os.path.expanduser(app.get("output", ""))
        if not template or not output:
            print(f"matugen-run: {name!r} left out: no template or output", file=sys.stderr)
            continue
        if not os.access(template, os.R_OK):
            print(f"matugen-run: {name!r} left out: can't read {template}", file=sys.stderr)
            continue
        # JSON strings are valid TOML basic strings.
        lines = [f"\n# {name} (added in the settings)", f"[templates.added{number}]",
                 f"input_path = {json.dumps(template)}", f"output_path = {json.dumps(output)}"]
        if app.get("hook"):
            lines.append(f"post_hook = {json.dumps(app['hook'])}")
        sections.append("\n".join(lines) + "\n")
    return "".join(sections)


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    config, apps, added, *options = sys.argv[1:]
    apps = {app for app in apps.split(",") if app}

    with open(config, encoding="utf-8") as source:
        text = source.read()
    active = os.path.join(os.path.dirname(os.path.abspath(config)), "active.toml")
    with open(active, "w", encoding="utf-8") as target:
        target.write(filtered(text, apps))
        target.write(added_sections(json.loads(added or "[]")))

    os.execvp("matugen", ["matugen", *options, "-c", active])


if __name__ == "__main__":
    main()
