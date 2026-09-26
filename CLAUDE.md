# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

olShell is a [Quickshell](https://quickshell.org) (QML) desktop shell for Hyprland. README.md is the user documentation and is kept current: its Structure tree, Settings table and IPC list are updated along with the code.

## Running

There is no build step, linter or test suite. Run the shell from the checkout:

```sh
quickshell -p .
quickshell -p . ipc call <target> <function> [args]   # e.g. launcher toggle, settings toggle
```

Quickshell reloads live when a `.qml` file changes. An in-place `sed -i` may not trigger the reload, so `touch shell.qml` afterwards.

The shell the user runs day to day is a deployed copy in `~/.config/olShell`, not this checkout. 
To test ask for killing the deployed shell, then start the checkout shell.
Deploy only when asked.
After deployment kill the checkout shell and restart the deployed one.

The running shell points Hyprland's `QS_CONFIG_PATH` (which the shortcuts' `qs ipc` calls use) at its own folder about a second after it starts and after every Hyprland config reload (`services/ConfigPath.qml`), so it doesn't need setting by hand. To check it:
```sh
hyprctl eval "hl.exec_cmd(\"sh -c 'env | grep QS_ > /tmp/qs-env'\")"; cat /tmp/qs-env
```

## Architecture

- **Imports:** Quickshell turns every directory into a module, so files are imported as `qs.<path>` (`import qs.config`, `qs.services`, `qs.components`, `qs.modules.Bar.Widgets`), never by relative path.
- **`shell.qml`** instantiates every module. Singletons are created lazily, so a service that has to exist from startup (to own an IPC target or a D-Bus name, or to apply a saved state) gets a dummy `readonly property var x: Service.prop` reference in `shell.qml`.
- **`config/`** holds singletons for state and configuration:
  - Each full-screen panel has a `*State.qml` singleton with `visible` and `toggle()`. Panels grab the keyboard, so every `toggle()` first closes all the other panels. A new panel must be added to every other State's `toggle()`, and its own `toggle()` must close them.
  - Settings flow `Defaults.qml` (factory values) → `Settings.qml` (reads the git-ignored `Settings.json`, clamps to `limits` / `choices`, and layers the user defaults from `UserDefaults.json`) → `Theme.qml` (what widgets bind to). A new setting touches `Defaults`, `Settings` (limits/choices and the property), `Theme` if it's visual, the row in `modules/Settings/SettingsPanel.qml`, translations, and the README table.
  - Colors: `GeneratedColors.qml` gives the active palette, either a fixed preset from `ThemePresets.qml` or matugen's `GeneratedColors.json`. `Theme` derives the rest from it.
- **`services/`** holds singletons wrapping system state and processes (audio, notifications server, lock/PAM, screenshots, matugen, system stats, zoom, blur). Most also expose an `IpcHandler`; so do the panels in `modules/`.
- **`modules/<Feature>/`** holds one feature each. Full-screen panels extend `components/ModalPanel.qml`, and the wallpaper and theme pickers extend `CarouselPanel.qml`. Bar widgets live in `modules/Bar/Widgets/`, are registered by id in `modules/Bar/BarWidgets.qml`, and are placed from `Settings.layout` through `WidgetZone` / `WidgetSlot`.
- **`scripts/`** holds Python helpers the QML runs through `Process`: wallpaper apply, screenshots, the lock-key watcher, the Hyprland shortcuts parser and the TUI window launcher. User text goes to scripts as arguments, never spliced into a shell string.
- **`matugen/`**: `quickshell.toml` is a self-contained matugen config (template paths are relative to the file) run by `services/Matugen.qml`. It themes the shell itself (`config/GeneratedColors.json`) and also Hyprland, Zen, alacritty, GTK and starship. Those outputs land in `~/.config/...` from templates stored here, so edit the template here, not the generated file.

## Conventions

- **Visible text:** every string goes through `I18n.tr("dotted.key", args...)`. Add the key to all three dictionaries in `config/Translations.qml` (en, fr, es); `{0}` / `{1}` are the placeholders.
- **Git-ignored runtime state:** `config/*.json` files (Settings, UserDefaults, ThemeState, LocaleState, GeneratedColors, NotificationActions). Back up `Settings.json` before anything that resets or bulk-changes settings.
- **Hyprland:** dynamic rules set via `hyprctl keyword` are wiped when Hyprland reloads its config (matugen triggers a reload shortly after login). Reapply them on `Hyprland.rawEvent` `configreloaded`. Layer-rule namespace matches are regexes, so anchor them with `^...$`.
- **Comments:** comments explain what an item is for, in full sentences, above properties and functions. Match that density.
- **Commit messages:** a single imperative sentence describing the user-visible change, with no type prefix (e.g. "Add tabs to the launcher: all, applications, files and the web").
