#!/usr/bin/env python3
"""Checks that the bar widgets follow the click rules (see ../SKILL.md, "Clicks
and hover"): the left click runs the widget's action and never opens a menu,
the middle click runs another action and never opens a menu either, the right
click opens a menu, a hover popup is fed by the mouse, and a hand cursor means a click does
something. It reads each MouseArea of modules/Bar/Widgets/*.qml, so it catches
the shape of a handler, not what the action really does.
Usage (from the repo root): check-clicks.py [Component ...]
Exits 1 when a widget breaks a rule.
"""
import re
import sys
from pathlib import Path

WIDGETS = Path("modules/Bar/Widgets")
# The insides of the tray's menus, not widgets of their own.
SKIPPED = {"TrayMenuItem", "TraySubmenu"}
# A menu being opened or toggled (closing one, `menu.open = false`, is fine).
MENU = re.compile(r"\.open\s*=\s*(!|true)")


def blocks(text, name):
    """The bodies of the `name { ... }` blocks of a QML file."""
    for match in re.finditer(r"\b" + name + r"\s*\{", text):
        depth, start = 0, match.end() - 1
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    yield text[start + 1:i]
                    break


def handler(body, name):
    """The code of a handler (`onClicked: ...`), a block or a single line."""
    match = re.search(r"\b" + name + r":\s*(?:\w+\s*=>\s*)?", body)
    if not match:
        return ""
    rest = body[match.end():]
    if rest.startswith("{"):
        return next(blocks("_" + rest, "_"), "")
    return rest.split("\n", 1)[0]


def branch(code, button):
    """What a click handler does for one button: the statement after its test."""
    match = re.search(r"mouse\.button\s*===\s*Qt\." + button + r"\)\s*", code)
    if not match:
        return None
    rest = code[match.end():]
    if rest.startswith("{"):
        return next(blocks("_" + rest, "_"), "")
    return re.split(r"\n|\belse\b", rest, maxsplit=1)[0]


def check(path):
    text = path.read_text()
    problems = []
    areas = list(blocks(text, "MouseArea"))
    for area in areas:
        buttons = re.search(r"acceptedButtons:\s*(.*)", area)
        buttons = buttons.group(1) if buttons else "LeftButton"
        clicked = handler(area, "onClicked")
        if "PointingHandCursor" in area and not clicked and "onWheel" not in area:
            problems.append("a hand cursor where a click does nothing")
        if not clicked:
            continue
        right = branch(clicked, "RightButton")
        middle = branch(clicked, "MiddleButton")
        if "RightButton" in buttons:
            # Without a test of its own, the right click is the last branch (TrayItem).
            if right is not None and not MENU.search(right):
                problems.append("a right click that doesn't open a menu: " + right.strip())
        menus = len(MENU.findall(clicked)) - (len(MENU.findall(right)) if right else 0)
        if "RightButton" not in buttons and MENU.search(clicked) or "RightButton" in buttons and right is not None and menus > 0:
            problems.append("a left click that opens a menu (the menu goes on the right click)")
        if "MiddleButton" in buttons and (middle is None or MENU.search(middle)):
            problems.append("a middle click that opens a menu, or has no branch of its own: " + (middle or "").strip())
    if "HoverPopup" in text and not any(
        "hoverEnabled: true" in area and "hoverEntered()" in area and "hoverExited()" in area for area in areas
    ):
        problems.append("a HoverPopup no MouseArea opens (hoverEnabled, hoverEntered() and hoverExited())")
    if re.search(r"acceptedButtons:.*RightButton", text) and "PopupMenu" not in text:
        problems.append("a right click accepted with no PopupMenu")
    return problems


def main():
    names = sys.argv[1:] or sorted(p.stem for p in WIDGETS.glob("*.qml") if p.stem not in SKIPPED)
    failed = 0
    for name in names:
        problems = check(WIDGETS / (name + ".qml"))
        for problem in problems:
            print(f"  BREAKS   {name}: {problem}")
        failed += bool(problems)
    print(f"click rules: {len(names) - failed} of {len(names)} widgets follow them")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
