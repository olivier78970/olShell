---
name: add-service
description: Add a service to olShell (a singleton in services/ wrapping a system process, D-Bus name, Hyprland state or file, with or without IPC calls) and wire it - the startup reference in shell.qml, the IpcHandler, process arguments, reapplying Hyprland rules, translations and the README. Use it whenever the user wants a feature that runs a command, watches the system, talks to a daemon or exposes IPC calls, even if they don't say "service".
---

# Adding a service to olShell

Services (`services/*.qml`) are `pragma Singleton`s created on first use. Most of the work is deciding whether it must exist from startup, because that is what is easy to forget. Copy a service of the same shape: `Zoom.qml` (IPC calls and a visible effect), `Weather.qml` (fetches and caches), `Blur.qml` (applies a saved setting to Hyprland), `LockKeys.qml` (a long-running watcher).

## Decide first

- **Does it need to exist from the start?** Yes if it owns an IPC target, owns a D-Bus name, watches something, or applies a saved state when the shell starts. Then add a dummy reference to `shell.qml` (`readonly property var x: Service.prop`, with a comment saying why, like the others). A service only used by a widget or panel needs none.
- **Process or in-process?** Run commands with `Process { command: [...] }` and pass user text as separate arguments, never spliced into a shell string. A helper script goes in `scripts/` (Python, run by the QML through `Process`).
- **Hyprland rules:** a rule set with `hyprctl keyword` is wiped when Hyprland reloads its config (matugen triggers one soon after login). Reapply on `Hyprland.rawEvent` `configreloaded`, and anchor layer-rule namespaces with `^...$` (they are regexes).
- **State kept between runs** goes in a git-ignored `config/*.json` (see `LauncherState.qml`), never in a panel.

## The places to edit

1. **`services/<Name>.qml`**: a comment on top saying what it does and its IPC calls; a comment above each property and function.
2. **IPC** (if any): an `IpcHandler { target: "<lowercase>" }` in the service, each function commented. It must answer while no panel is built.
3. **`shell.qml`**: the startup reference, when needed (above).
4. **A setting** it comes with: the `add-setting` skill. **A panel or widget** for it: `add-panel` / `add-bar-widget`.
5. **Translations** for anything shown to the user (`I18n.tr`, en/fr/es in `config/Translations.qml`).
6. **`README.md`** (search with `grep -n … | cut -c1-200`): the Structure tree's `services/` lines, the **IPC** block for each call, and a description in the feature's section.

## Check

```sh
.claude/scripts/check-translations.py
```

## Test

With the checkout shell running (the `test-deploy` skill): call each IPC function with `quickshell -p . ipc call <target> <function>`, then read the log (`shell.sh log`) for `ReferenceError`, `TypeError`, `Unable to assign` and process errors. If it applies Hyprland state, also run `hyprctl reload` and check the state is back. Tell the user what to look at; never take screenshots.
