---
name: add-agent
description: Add an AI coding agent to olShell's agent bar widget, next to Claude, Codex, Grok and Antigravity - its AgentUsage in services/Agents.qml (CLI, desktop app or web app, icon), the usage script reading its plan and limits, its choice in Settings.agentDefault, translations and docs. Use it whenever the user wants another agent or AI CLI (opencode, Cursor, Copilot, Kiro...) in the agent widget or its menu, or as the default agent, or to swap one agent for another, even if they don't say "add an agent".
---

# Adding an agent to the agent widget

The agent widget (`modules/Bar/Widgets/AgentButton.qml`) knows nothing about any agent: it draws whatever `services/Agents.qml` lists. Each agent is one `AgentUsage` (`services/AgentUsage.qml`) with a CLI, a desktop app (or a web app standing in for it) and a script reading its plan and usage limits. Copy the agent whose login is stored like the new one's (see Logins below).

It adds a choice to a setting, so it is a medium change: a new branch first (CLAUDE.md, Branches).

## Find out first

Look these up before writing anything, and ask the user what can't be found:

- **The CLI**: the executable on the PATH (`which <name>`; the menu hides an agent whose CLI isn't found) and its Arch package (`pacman -Qo $(which <name>)`), for the docs.
- **The desktop app**: the command starting it, and whether running it again brings the open window forward. None (or none on Linux): `desktop: []`. A web app can stand in for it: `webApp: "<name>"` names one of `Settings.webApps` (any case), opened when the desktop app isn't installed (Grok's `webApp: "Grok"`); ask the user whether they want one.
- **Its login and usage endpoint**: where the CLI keeps its token, and the endpoint its own usage or status command asks (Claude Code's `/usage`, Codex's `/status`, Grok Build's `/usage`). Read the source rather than guessing: for an open-source CLI, shallow-clone it into the scratchpad and grep it locally (GitHub's code search allows about 10 queries a minute); for a closed binary, `strings` on it gives its endpoints, `v1internal:` methods and OAuth client ids. Tools that already read the quota (CodexBar, AIUsage) show the request and the answer's shape.
- **Its plan and limits**: what the endpoint answers, and how its windows map to minutes (300 for 5 hours, 10080 for a week).

Then call the endpoint once with the user's real login, printing only status codes and field names, before wiring anything: a maker may have stopped serving that CLI (Google refuses Gemini CLI to individual accounts with `UNSUPPORTED_CLIENT` and points to Antigravity). If the agent has no usage endpoint its login can reach, stop and ask the user: `AgentUsage` needs a script, and an agent without limits is a change to `AgentUsage` and the menu, not something to fake in a script.

## Logins

The usage script reads the login and sends its token only to its maker's endpoints, keeping only the plan and the limits.

- **A file** (`~/.codex/auth.json`, `~/.grok/auth.json`, with the environment variable that moves its folder): copy `codex-usage.py` or `grok-usage.py`.
- **The keyring** (the Secret Service, as `agy` does): read it with `secret-tool lookup <attribute> <value>...` (copy `antigravity-usage.py`). The permission system refuses you any look at the keyring, even listing entries, so ask the user for the entry's label in Seahorse ("Passwords and Keys"). Go programs label it `Password for '<username>' on '<service>'`, which gives the attributes `service <service> username <username>`.
- **Refreshing**: the script never refreshes or writes the token (the CLI does that when it runs): renewing can replace the refresh token the CLI keeps (Anthropic and OpenAI rotate theirs) and sign it out. The one exception is an access token too short-lived to wait for the CLI (Google's: an hour) whose refresh token the maker doesn't rotate: the script gets a new one in memory with the CLI's public OAuth client and never writes the login (`antigravity-usage.py`). Ask the user before making another such exception.
- **An embedded OAuth client** id or secret (public by design for an installed app) makes GitHub's push protection refuse the push, once for the secret and once for the id. Tell the user before shipping; the `ship` skill says how to get it through.

## The places to edit

1. **`scripts/<key>-usage.py`**, `chmod +x`. Its docstring's first line is what `docs/structure.md` shows. Standard library only (`urllib`), with a timeout. It prints one JSON object and nothing else:
   - `{"plan": "Pro", "limits": [{"minutes": 300, "percent": 42, "resetsAt": "2026-11-13T18:00:00Z"}, ...]}`, the limits the plan has (`resetsAt` may be null). When several limits share a window (Antigravity's of each model group), each also has a `"name"` (the group), shown before the window's name;
   - or `{"error": R}`: `"login"` (no login, or the endpoint refused it: running the CLI signs in again), `"network"`, or `"rateLimit"` with `"retryAfter"` (seconds, when the endpoint says). These are the only errors the menu knows (`agent.error.*`); a new one needs its own key in en, fr and es.
2. **`config/Paths.qml`**: `readonly property string <key>UsageScript: Quickshell.shellPath("scripts/<key>-usage.py")` in the agent widget's group, and the agents named in its comment.
3. **`services/Agents.qml`**: a `readonly property AgentUsage <key>: AgentUsage { key, name, icon, command, desktop, webApp (optional), script: Paths.<key>UsageScript, active: root.active }`, with a comment when it needs one. The `key` is the property's name and the setting's value; the `icon` is a Nerd Font glyph (written as an escape, see CLAUDE.md). Add `root.<key>` to `all`, in the order of `Settings.choices.agentDefault`.
4. **`config/Settings.qml`**: the key added to `choices.agentDefault`. The default (`Defaults.qml`) stays `claude`.
5. **Translations**: `.claude/scripts/add-translation.py settings.agentDefault.<key> "<name>" "<fr>" "<es>" --after settings.agentDefault.<last key>` (product names usually stay the same), and the new agent named in `agent.none` in all three dictionaries.
6. **Every place that names the agents**, comments included: `grep -rn -i '<an existing agent's key>' --exclude-dir=.git . | grep -v scripts/` lists them (the headers of `Agents.qml`, `AgentButton.qml`, `AgentUsage.qml`, the comments above `Settings.agentDefault` and `SettingsModule.qml`'s `choose()`).
7. **Docs**: `grep -n -i '<an existing agent's key>' docs/*.md | cut -c1-200`, then read only those lines:
   - `docs/system.md`, the **Agent** section: the agents in its first line, the CLI and its package, the desktop app, the menu's commands and limits, and the paragraph linking each script with the login and endpoint it reads.
   - `docs/settings.md`, the **Default agent** row; `docs/ipc.md`, the `agent` line.
   - `.claude/scripts/structure.py`, so `docs/structure.md` lists the script.

Swapping an agent for another is the same list run twice: take the old one out of every place (the `remove-feature` skill's leftovers check), then add the new one.

## Check

```sh
.claude/skills/add-agent/scripts/check-agents.py   # every agent, in the places it can read
.claude/scripts/check-all.sh                       # runs it too
```

It reads neither the comments of step 6 nor `agent.none`: the step's grep is the check for those.

## Test

- The script alone first: `python3 scripts/<key>-usage.py` prints one JSON line, with a plan and limits once signed in. Test the parsing on a sample answer too (load the script with `importlib` and call its parsing function), since the real account may not have every window.
- Then in the checkout shell (the `test-deploy` skill): `shell.sh ipc agent usage` lists the agent's plan and limits, and `shell.sh errors` prints nothing. The call answers with the last reading and starts a new one (reused for 30 seconds), so after a fix ask twice before believing an error. Tell the user what to look at: the agent's section in the widget's menu, its two buttons, and the **Default agent** list. Don't change their default agent through IPC without asking.
