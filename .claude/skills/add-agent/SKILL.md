---
name: add-agent
description: Add an AI coding agent to olShell's agent bar widget, next to Claude and Codex - its AgentUsage in services/Agents.qml (command line, desktop app, icon), the usage script reading its plan and limits, the Paths entry, its choice in Settings.agentDefault, its name in the default agent's list (en/fr/es) and the docs. Use it whenever the user wants another agent or AI CLI (Gemini CLI, opencode, Cursor, Copilot...) in the agent widget or its menu, or as the default agent, even if they don't say "add an agent".
---

# Adding an agent to the agent widget

The agent widget (`modules/Bar/Widgets/AgentButton.qml`) knows nothing about any agent: it draws whatever `services/Agents.qml` lists. Each agent is one `AgentUsage` (`services/AgentUsage.qml`) with a command line, a desktop app and a script reading its plan and usage limits. Copy Codex, the agent whose wiring is the most complete: `codex` in `Agents.qml` and `scripts/codex-usage.py`.

It adds a choice to a setting, so it is a medium change: a new branch first (CLAUDE.md, Branches).

## Find out first

Look these up for the agent (its docs, its source, the installed package) before writing anything, and ask the user about what can't be found:

- **The command line**: the executable on the PATH (`which <name>`; the widget hides an agent whose command isn't found) and its Arch package, for the docs.
- **The desktop app**, if it has one: the command starting it (`desktop: ["..."]`), and whether running it again brings the open window forward. None: `desktop: []`, and the menu hides the desktop button. A web app can stand in for it (Grok's `webApp: "Grok"`): `webApp` names one of `Settings.webApps` (any case), opened by the desktop button and the middle click when the desktop app isn't installed; ask the user whether they want one.
- **Its login**: the file the CLI keeps its token in (and the environment variable moving that folder, like `CODEX_HOME`), and the endpoint its own usage or status command asks (Claude Code's `/usage`, Codex's `/status`). Read that command's source rather than guessing the URL.
- **Its plan and limits**: what the endpoint answers, and how its windows map to minutes (300 for 5 hours, 10080 for a week).

If the agent has no usage endpoint the CLI can reach with its own login, stop and ask the user: `AgentUsage` needs a script, and the menu would show an error under the agent's name. Showing an agent without limits is a change to `AgentUsage` and the menu, not something to fake in a script.

## The places to edit

1. **`scripts/<key>-usage.py`**: the usage script, modeled on `codex-usage.py`. Its docstring's first line is what `docs/structure.md` shows. It prints one JSON object and nothing else:
   - `{"plan": "Pro", "limits": [{"minutes": 300, "percent": 42, "resetsAt": "2026-11-13T18:00:00Z"}, ...]}`, the limits the plan has (`resetsAt` may be null). When several limits share a window (Antigravity's 5-hour and weekly limits of each model group), each also has a `"name"` (the group), which the menu shows before the window's name;
   - or `{"error": R}`: `"login"` (no login, or the endpoint refused it: running the agent signs in again), `"network"`, or `"rateLimit"` with `"retryAfter"` (seconds, when the endpoint says). These are the only errors the menu knows (`agent.error.*` in the translations); a new one needs its own key in en, fr and es.
   - It reads the token and sends it only to its maker's endpoint, keeps only the plan and the limits, and never refreshes or writes the token (the CLI does that when it runs): renewing a token can replace the refresh token the CLI keeps (Anthropic and OpenAI rotate theirs) and sign it out. The one exception is a short-lived access token whose refresh token the maker doesn't rotate (Google's, for Antigravity: an hour): the script may get a new one in memory with the CLI's public client, never writing the CLI's login (see `antigravity-usage.py`). A login kept in the keyring is read with `secret-tool lookup` (see the same script). Ask the user before making another such exception. Standard library only (`urllib`), with a timeout.
   - `chmod +x` it.
2. **`config/Paths.qml`**: `readonly property string <key>UsageScript: Quickshell.shellPath("scripts/<key>-usage.py")`, in the agent widget's group, with its comment saying which agents' scripts these are.
3. **`services/Agents.qml`**:
   - a `readonly property AgentUsage <key>: AgentUsage { key, name, icon, command, desktop, webApp (optional), script: Paths.<key>UsageScript, active: root.active }`. The `key` is the property's name and the setting's value. The `icon` is a Nerd Font glyph.
   - `<key>` added to `all`, in the order of `Settings.choices.agentDefault`.
   - the header comment, which names the agents and their desktop apps.
4. **`config/Settings.qml`**: the key added to `choices.agentDefault`, and the agents named in the comment above `agentDefault`. The default (`Defaults.qml`) stays `claude`.
5. **`modules/Settings/SettingsModule.qml`**: the key added to `agentDefault (claude or codex, if installed)` in the comment above `choose()`. Its `allowed` check already accepts any choice that is installed.
6. **Translations**: `.claude/scripts/add-translation.py settings.agentDefault.<key> "<CLI name>" "<fr>" "<es>" --after settings.agentDefault.<last key>`. Product names usually stay the same in all three. Also update `agent.none` ("install Claude Code or Codex") in all three dictionaries to name the new agent.
7. **Comments naming the agents**: `AgentButton.qml`'s header ("Claude and Codex", "Claude Desktop or ChatGPT") and `AgentUsage.qml`'s list of scripts. Find the rest with `grep -rn -i 'codex' --include='*.qml' .`.
8. **Docs** (`grep -n -i 'codex' docs/*.md | cut -c1-200`, then read only those lines):
   - `docs/system.md`, the **Agent** section: the agents in its first line, the command line and its package (left click), the desktop app (middle click), the menu's limits, and the paragraph linking each script, with the login file and endpoint it reads.
   - `docs/settings.md`, the **Default agent** row: the command in backticks and the choice in the values column.
   - `docs/ipc.md`, the `agent` line, which names the desktop apps.
   - `.claude/scripts/structure.py`, so `docs/structure.md` lists the script.

## Check

```sh
.claude/skills/add-agent/scripts/check-agents.py   # every agent, in every place above
.claude/scripts/check-all.sh
```

`check-agents.py` checks every agent at once, from `choices.agentDefault`. It doesn't read the comments of step 7 or `agent.none`, so grep those for the agents' names.

## Test

- The script alone first: `python3 scripts/<key>-usage.py` prints one JSON line. Signed in, it has a plan and limits; with the login file moved away (via its environment variable, never by moving the user's file), it prints `{"error": "login"}`.
- Then in the checkout shell (the `test-deploy` skill): `shell.sh ipc agent usage` lists the new agent with its plan and limits, and `shell.sh errors` prints nothing. Tell the user what to look at: the agent's section in the widget's menu, its two buttons, and the **Default agent** list in the settings (the new agent picked as the default, then a left and a middle click on the widget). Don't change their default agent through IPC without asking.
