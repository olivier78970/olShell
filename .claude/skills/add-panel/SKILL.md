---
name: add-panel
description: Add a new full-screen panel to olShell (a ModalPanel like the launcher, settings, power or chat AI panels, opened by IPC, a keybinding or a bar button) with everything a panel needs - its State singleton closing the other panels, a lazily built Module with its IpcHandler, shell.qml, a placement setting, translations and the README. Use it whenever the user wants a new panel, popup window, overlay, picker or "screen" that grabs the keyboard, or wants to turn an existing popup into a proper panel, even if they don't say "panel".
---

# Adding a full-screen panel to olShell

A panel touches every other panel. Panels grab the keyboard, so exactly one may be open, and they all open through `Panels.open()` (`config/Panels.qml`), which closes the others and waits for their closing animation. A panel missing from its `all` list leaves two panels fighting for focus. Copy the chat AI panel: it is the most recent one and has every part (`config/ChatAiState.qml`, `modules/ChatAi/ChatAiModule.qml`, `modules/ChatAi/ChatAiPanel.qml`).

## Decide first

- **Name and ids**: a feature name (`ChatAi`), its State singleton (`ChatAiState`), its placement id (`chatAi`, which gives `chatAiPlacement` and `settings.placement.chatAi`), and its IPC target (lower case, `chatai`).
- **Base component**: `components/ModalPanel.qml` for a panel, or `CarouselPanel.qml` for a picker over cards (like wallpapers and themes).
- **Built only while open** (the default for new panels): a `*Module.qml` holds the IpcHandler and a `LazyLoader` active while `Linger { when: <State>.visible }` is active, so the panel exists only while shown and during its closing animation. Anything the panel keeps between openings (a picked tab, a selection, a draft) goes in its State or in a service, never in the panel.
- **Default placement**: one of `Settings.panelPlacements` (`center`, `bar-center`, …).
- **How it opens**: IPC always, and optionally a bar button (use the `add-bar-widget` skill for that) and a Hyprland keybinding. For a keybinding, suggest the line to the user; `~/.config/hypr` is outside the project, so ask before editing it.

## The places to edit

1. **`config/<Name>State.qml`**: a `pragma Singleton` with `property bool visible: false` and `toggle()`. `toggle()` closes it when visible, else opens it through `Panels.open(root, () => root.visible = true)` (copy `ChatAiState.qml`).
2. **`config/Panels.qml`**: add `<Name>State` to its `all` list, so opening any other panel closes this one. The checker lists a panel State missing from it.
3. **`modules/<Name>/<Name>Panel.qml`**: `ModalPanel { open: <Name>State.visible; onCloseRequested: <Name>State.visible = false; placement: Settings.<id>Placement; focusTarget: … }`. Size it with `maxPanelWidth` / `maxPanelHeight` (or `fitScreen`), reset what should start fresh in `onOpened`, and close on Escape. Start the file with a comment saying what the panel is, its IPC call and its keys, like the others.
4. **`modules/<Name>/<Name>Module.qml`**: a `Scope` holding the `IpcHandler` (`target: "<ipc>"`, at least `toggle()`, each function with a comment) and the `Linger` + `LazyLoader`. The IPC functions must work while the panel isn't built, so they go through the State or a service, never the panel.
5. **`shell.qml`**: `import qs.modules.<Name>` and `<Name>Module {}` with the other modules. A service that has to exist from startup gets the dummy reference CLAUDE.md describes.
6. **The placement setting** `<id>Placement`: it follows the `add-setting` skill, and a placement has a few extra places:
   - `Defaults.qml`: the default placement.
   - `Settings.qml`: `<id>Placement: root.panelPlacements` in `choices`, the id in `placementKeys` (so **All panels** moves it too), the property and the JsonAdapter entry.
   - `SettingsPages.qml`: a `dropdown` row with `positionIcon: true` on the `panels` page, after the other placements. Its options come from `optionsOf` automatically, because its choices are `Settings.panelPlacements`.
   - `settings.placement.<id>` in en, fr and es.
   - `SettingsModule.qml`: add the key to `choose()`'s comment.
7. **Translations** for everything the panel shows, via `I18n.tr`, in en, fr and es.
8. **`README.md`** (search it with `grep -n … | cut -c1-200`; its lines are very long):
   - the Structure tree: the State, Module and Panel files;
   - the **IPC** block: `quickshell -p . ipc call <ipc> toggle` and the other calls;
   - the Settings table: add the panel's name to the **Placement of each panel** row, and a row for any setting of its own;
   - the **From a script** choices table: add `<id>Placement` to the placement row;
   - a section of its own describing the panel, its keys and its IPC calls.

## Check

```sh
.claude/skills/add-panel/scripts/check-panel.sh <Name>State <id> <ipc>   # e.g. ChatAiState chatAi chatai
.claude/skills/add-setting/scripts/check-setting.sh <id>Placement choice
.claude/scripts/check-translations.py
```

The panel checker also verifies that every panel State is in `Panels.all` and opens through `Panels.open()`.

## Test

With the checkout shell running (see CLAUDE.md):

- `quickshell -p . ipc call <ipc> toggle` opens it; again closes it.
- Opening another panel (e.g. `launcher toggle`) closes it.
- Escape and a click outside close it.
- `settings choose <id>Placement bar-left`, then reopen: it moves.
- Call each IPC function while the panel is closed: none may fail because the panel isn't built.
- Watch the log for QML errors, and tell the user what to look at.
