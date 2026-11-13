#!/usr/bin/env python3
"""Checks that every agent of the agent widget is wired everywhere an agent is
listed: the choices of Settings.agentDefault, its AgentUsage in
services/Agents.qml and its place in Agents.all (in the same order), its usage
script and the Paths property naming it, its name in the default agent's list
(en, fr, es), the SettingsModule comment, and the docs.

Usage (from the repo root): check-agents.py
Prints OK or MISSING for each place, and exits 1 when anything is missing.
"""

import os
import re
import sys

missing = 0


def read(path):
    with open(path, encoding="utf-8") as file:
        return file.read()


# Prints OK or MISSING for one place.
def check(label, ok):
    global missing
    print(("  OK       " if ok else "  MISSING  ") + label)
    if not ok:
        missing += 1


settings = read("config/Settings.qml")
agents = read("services/Agents.qml")
paths = read("config/Paths.qml")
translations = read("config/Translations.qml")
module = read("modules/Settings/SettingsModule.qml")
system = read("docs/system.md")
settings_doc = read("docs/settings.md")
ipc_doc = read("docs/ipc.md")
structure = read("docs/structure.md")

choices = re.search(r"agentDefault: \[([^\]]*)\]", settings)
keys = re.findall(r'"(\w+)"', choices.group(1)) if choices else []
if not keys:
    print("no choices.agentDefault in config/Settings.qml")
    sys.exit(1)

# Each AgentUsage of Agents.qml: its property name and its body.
blocks = dict(re.findall(r"readonly property AgentUsage (\w+): AgentUsage \{(.*?)\n  \}", agents, re.S))
listed = re.search(r"readonly property var all: \[([^\]]*)\]", agents)
order = re.findall(r"root\.(\w+)", listed.group(1)) if listed else []

print("Agents (choices.agentDefault): " + ", ".join(keys))
check("Agents.all lists them in the order of choices.agentDefault", order == keys)
agent_line = next((line for line in module.splitlines() if "agentDefault (" in line), "")

for key in keys:
    print(f"Agent '{key}':")
    body = blocks.get(key, "")
    check(f"Agents.qml: readonly property AgentUsage {key}", bool(body))
    check(f'Agents.qml: key: "{key}"', f'key: "{key}"' in body)
    for field in ("name", "icon"):
        check(f"Agents.qml: {field}", re.search(rf'{field}: "[^"]+"', body) is not None)
    command = re.search(r'command: \["([^"]+)"', body)
    check("Agents.qml: command", command is not None)
    check("Agents.qml: desktop (may be [] when there is no desktop app)", "desktop:" in body)

    script = re.search(r"script: Paths\.(\w+)", body)
    check("Agents.qml: script: Paths.<name>", script is not None)
    if script:
        file = re.search(rf'property string {script.group(1)}: Quickshell\.shellPath\("([^"]+)"\)', paths)
        check(f"Paths.qml: {script.group(1)}", file is not None)
        if file:
            check(f"{file.group(1)} exists", os.path.isfile(file.group(1)))
            name = os.path.basename(file.group(1))
            check(f"docs/structure.md lists {name} (run .claude/scripts/structure.py)", name in structure)
            check(f"docs/system.md (Agent) links {name}", name in system)

    count = len(re.findall(rf'^\s*"settings\.agentDefault\.{key}":', translations, re.M))
    check(f"settings.agentDefault.{key} x{count} (en, fr, es)", count >= 3)
    check(f"SettingsModule.qml comment: agentDefault ({key} ...)", re.search(rf"\b{key}\b", agent_line) is not None)

    if command:
        name = command.group(1)
        check(f"docs/system.md (Agent) names `{name}`", f"`{name}`" in system)
        row = next((line for line in settings_doc.splitlines() if "Default agent" in line), "")
        check(f"docs/settings.md Default agent row names `{name}`", f"`{name}`" in row)
    desktop = re.search(r'desktop: \["([^"]+)"', body)
    if desktop:
        check(f"docs/system.md (Agent) names its desktop app `{desktop.group(1)}`", f"`{desktop.group(1)}`" in system)

print(f"{missing} missing" if missing else "all agents wired")
sys.exit(1 if missing else 0)
