#!/usr/bin/env python3
"""Lists the Hyprland config's shortcuts with the Super key, as JSON.

Usage: list-shortcuts.py [CONFIG]   (default: ~/.config/hypr/hyprland.lua)

A Lua config binds each shortcut to a Lua function, so `hyprctl binds` only
knows its keys: what it does is read here from the config's own
`hl.bind(KEYS, ACTION, OPTIONS)` calls, following `require("name")` to the
files next to it. Variables holding strings (`terminal = "alacritty"`,
`mainMod = "SUPER"`, "a" .. b concatenations) are resolved on the way.

Prints {"shortcuts": [...], "running": N}: each shortcut is
  {"keys": ["Super", "Shift", "W"], "action": ACTION, "arg": ..., "command": ...,
   "description": ...}
where ACTION is a kind the shell describes in its own language ("exec",
"shell", "close", "focusWorkspace"...; "other" with the raw call in "arg"),
and "running" is how many binds with Super Hyprland itself has, to spot any
this couldn't read. Shortcuts without Super (media keys, Print...) are left out.
"""

import json
import os
import re
import subprocess
import sys

CONFIG = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/.config/hypr/hyprland.lua")

# Keycodes (code:N) of the keys a config usually names that way.
KEYCODES = {**{10 + i: str((i + 1) % 10) for i in range(10)},
            79: "Keypad 7", 80: "Keypad 8", 81: "Keypad 9", 83: "Keypad 4", 84: "Keypad 5",
            85: "Keypad 6", 87: "Keypad 1", 88: "Keypad 2", 89: "Keypad 3", 90: "Keypad 0"}
MODIFIERS = {"SUPER": "Super", "MOD4": "Super", "WIN": "Super", "SHIFT": "Shift", "CTRL": "Ctrl",
             "CONTROL": "Ctrl", "ALT": "Alt", "MOD1": "Alt", "ALTGR": "AltGr"}
KEYS = {"RETURN": "Enter", "ENTER": "Enter", "SPACE": "Space", "TAB": "Tab", "ESCAPE": "Esc",
        "BACKSPACE": "Backspace", "DELETE": "Delete", "PRINT": "Print Screen",
        "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
        # The shell translates these (the "@..." ones).
        "MOUSE:272": "@clickLeft", "MOUSE:273": "@clickRight", "MOUSE:274": "@clickMiddle",
        "MOUSE_UP": "@scrollUp", "MOUSE_DOWN": "@scrollDown"}


def strip_comments(source):
    """The Lua source without its comments, strings left intact."""
    out, i, n = [], 0, len(source)
    while i < n:
        c = source[i]
        if source.startswith("--", i):
            block = re.match(r"--\[(=*)\[", source[i:])
            if block:
                end = source.find("]" + block.group(1) + "]", i)
                i = n if end < 0 else end + len(block.group(1)) + 2
            else:
                end = source.find("\n", i)
                i = n if end < 0 else end
            continue
        if c in "\"'":
            j = i + 1
            while j < n and source[j] != c and source[j] != "\n":
                j += 2 if source[j] == "\\" else 1
            out.append(source[i:j + 1])
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def load(path, seen):
    """The config's statements, with the files it requires inlined."""
    if path in seen or not os.path.isfile(path):
        return ""
    seen.add(path)
    with open(path, encoding="utf-8") as f:
        source = strip_comments(f.read())
    base = os.path.dirname(path)
    return re.sub(r'require\s*\(?\s*["\']([^"\']+)["\']\s*\)?',
                  lambda m: "\n" + load(os.path.join(base, m.group(1).replace(".", "/") + ".lua"), seen) + "\n",
                  source)


def split_top(text, sep=","):
    """`text` split on `sep` outside brackets and strings."""
    parts, depth, current, quote = [], 0, "", None
    for c in text:
        if quote:
            current += c
            if c == quote:
                quote = None
            continue
        if c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == sep and depth == 0:
            parts.append(current.strip())
            current = ""
            continue
        current += c
    if current.strip():
        parts.append(current.strip())
    return parts


def call_args(source, start):
    """The text between the parenthesis at `start` and its match, and the index after it."""
    depth, quote = 0, None
    for i in range(start, len(source)):
        c = source[i]
        if quote:
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return source[start + 1:i], i + 1
    return source[start + 1:], len(source)


def evaluate(expr, variables):
    """A string expression's value (literals, variables, ..); None if it's anything else."""
    value = ""
    for part in split_top(expr.replace("..", "\0"), "\0"):
        part = part.strip()
        if re.fullmatch(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'', part):
            value += bytes(part[1:-1], "utf-8").decode("unicode_escape")
        elif re.fullmatch(r"-?\d+(\.\d+)?", part):
            value += part
        elif part in variables:
            value += variables[part]
        else:
            return None
    return value


def table(expr, variables):
    """A { key = value, ... } table's string/number/boolean fields."""
    fields = {}
    inner = expr.strip()
    if inner.startswith("{") and inner.endswith("}"):
        for item in split_top(inner[1:-1]):
            m = re.fullmatch(r"(\w+)\s*=\s*(.+)", item.strip(), re.S)
            if m:
                raw = m.group(2).strip()
                fields[m.group(1)] = raw == "true" if raw in ("true", "false") else evaluate(raw, variables)
    return fields


def key_labels(keys):
    labels = []
    for part in (p.strip() for p in keys.split("+")):
        up = part.upper()
        if up in MODIFIERS:
            labels.append(MODIFIERS[up])
        elif up in KEYS:
            labels.append(KEYS[up])
        elif up.startswith("CODE:") and up[5:].isdigit():
            labels.append(KEYCODES.get(int(up[5:]), part))
        elif up.startswith("XF86"):
            labels.append(re.sub(r"(?<=[a-z])(?=[A-Z])", " ", part[4:]))
        elif len(part) == 1:
            labels.append(part.upper())
        else:
            labels.append(part[:1].upper() + part[1:])
    return labels


def describe(action, variables):
    """What an hl.dsp... call does, as the shell describes it."""
    m = re.fullmatch(r"hl\.dsp\.([\w.]+)\s*\((.*)\)", action.strip(), re.S)
    if not m:
        return {"action": "other", "arg": action.strip()}
    name, raw = m.group(1), m.group(2).strip()
    args = table(raw, variables) if raw.startswith("{") else {}
    if name == "exec_cmd":
        command = evaluate(raw, variables) or raw
        ipc = re.search(r"\bipc\s+call\s+(\S+)\s+(\S+)(?:\s+(\S+))?", command)
        if re.search(r"\b(qs|quickshell)\b", command) and ipc:
            return {"action": "shell", "arg": "%s.%s" % (ipc.group(1), ipc.group(2)), "value": ipc.group(3) or "",
                    "command": command}
        # "pidof app || app": the app is what it runs.
        shown = re.sub(r"^pidof\s+\S+\s*\|\|\s*", "", command.strip())
        return {"action": "exec", "arg": shown.split()[0] if shown else command, "command": shown}
    if name == "window.close":
        return {"action": "close"}
    if name == "window.float":
        return {"action": "float"}
    if name == "window.fullscreen":
        return {"action": "fullscreen"}
    if name == "window.drag":
        return {"action": "drag"}
    if name == "window.resize":
        return {"action": "resize"}
    if name == "window.move" and "workspace" in args:
        return {"action": "moveToWorkspace", "arg": str(args["workspace"])}
    if name == "focus" and "direction" in args:
        return {"action": "focusDirection", "arg": str(args["direction"])}
    if name == "focus" and "workspace" in args:
        workspace = str(args["workspace"])
        if workspace in ("e+1", "+1", "r+1", "m+1"):
            return {"action": "nextWorkspace"}
        if workspace in ("e-1", "-1", "r-1", "m-1"):
            return {"action": "previousWorkspace"}
        return {"action": "focusWorkspace", "arg": workspace}
    if name == "workspace.toggle_special":
        return {"action": "toggleSpecial", "arg": evaluate(raw, variables) or raw}
    if name == "exit":
        return {"action": "exit"}
    return {"action": "other", "arg": "%s(%s)" % (name, raw)}


def main():
    source = load(CONFIG, set())
    variables, shortcuts = {}, []
    # Statements in order, so a variable is known by the binds after it.
    token = re.compile(r"(?:\blocal\s+)?\b([A-Za-z_]\w*)\s*=(?!=)|\bhl\.bind\s*\(")
    i = 0
    while True:
        m = token.search(source, i)
        if not m:
            break
        if m.group(1):
            # An assignment: its value runs to the end of the line, or further
            # while a `..` concatenation carries on.
            end = m.end()
            line_end = source.find("\n", end)
            expr = source[end:line_end if line_end >= 0 else None]
            while expr.rstrip().endswith("..") and line_end >= 0:
                next_end = source.find("\n", line_end + 1)
                expr += source[line_end:next_end if next_end >= 0 else None]
                line_end = next_end
            value = evaluate(expr.strip(), variables)
            if value is not None:
                variables[m.group(1)] = value
            i = m.end()
            continue
        args, i = call_args(source, m.end() - 1)
        parts = split_top(args)
        if len(parts) < 2:
            continue
        keys = evaluate(parts[0], variables)
        if keys is None:
            continue
        options = table(parts[2], variables) if len(parts) > 2 else {}
        labels = key_labels(keys)
        if "Super" not in labels:
            continue
        shortcut = {"keys": labels, **describe(parts[1], variables)}
        if options.get("description"):
            shortcut["description"] = options["description"]
        shortcuts.append(shortcut)

    try:
        binds = json.loads(subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=5).stdout)
        # Super is bit 6 (64) of a bind's modifier mask.
        running = sum(1 for bind in binds if bind.get("modmask", 0) & 64)
    except Exception:
        running = -1
    print(json.dumps({"shortcuts": shortcuts, "running": running}))


main()
