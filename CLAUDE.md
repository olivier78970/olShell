# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

olShell is a [Quickshell](https://quickshell.org) (QML) desktop shell for Hyprland. README.md is the user documentation and is kept current: its Structure tree, Settings table, From a script lists and IPC list are updated along with the code. README.md is over 100 KB, and many paragraphs are a single line of thousands of characters, so don't read it whole: find lines with `grep -n '<pattern>' README.md | cut -c1-200`, then read only those.

## Skills and checks

The recurring changes each have a project skill (`.claude/skills/`) listing every place they touch. Use it rather than working from memory:

- **`add-setting`**: a new setting.
- **`add-panel`**: a new full-screen panel.
- **`add-bar-widget`**: a new bar widget.
- **`test-deploy`**: running the checkout, reading its log, deploying.

There is no build step, linter or test suite. The checks are scripts, run from the repo root:
- `.claude/scripts/check-translations.py`: en, fr and es have the same keys and placeholders, and every literal `I18n.tr` key exists.
- The skills' own checkers: `check-setting.sh`, `check-panel.sh` (it also checks that every panel's `toggle()` closes all the others) and `check-widget.sh`.

## Running

The shell the user runs day to day is a **deployed copy** of master in `~/.config/olShell`, not this checkout, and only one shell may run at a time. Before testing, ask the user before stopping the deployed shell. Deploy only when asked. `.claude/skills/test-deploy/scripts/shell.sh` does the switching, the log and the deploy, and backs up the settings first.

Quickshell reloads live when a `.qml` file changes. An in-place `sed -i` may not trigger the reload, so `touch shell.qml` afterwards. Test through IPC (`quickshell -p . ipc call <target> <function> [args]`) and the log, not screenshots: the user looks at the shell themselves.

## Architecture

The per-file tree is in README.md's Structure section.

- **Imports:** Quickshell turns every directory into a module, so files are imported as `qs.<path>` (`import qs.config`, `qs.services`, `qs.components`, `qs.modules.Bar.Widgets`), never by relative path.
- **`shell.qml`** instantiates every module. Singletons are created lazily, so a service that has to exist from startup (to own an IPC target or a D-Bus name, or to apply a saved state) gets a dummy `readonly property var x: Service.prop` reference in `shell.qml`.
- **`config/`** holds singletons for state and configuration:
  - Each full-screen panel has a `*State.qml` singleton with `visible` and `toggle()`. Panels grab the keyboard, so every `toggle()` first closes all the other panels.
  - Settings flow `Defaults.qml` (factory values) → `Settings.qml` (reads the git-ignored `Settings.json`, clamps to `limits` / `choices`, and layers the user defaults from `UserDefaults.json`) → `Theme.qml` (what widgets bind to for the look). The settings panel's categories and rows are in `modules/Settings/SettingsPages.qml`.
  - Colors: `GeneratedColors.qml` gives the active palette, either a fixed preset from `ThemePresets.qml` or matugen's `GeneratedColors.json`. `Theme` derives the rest from it.
- **`services/`** holds singletons wrapping system state and processes (audio, notifications server, lock/PAM, screenshots, matugen, system stats, zoom, blur, the synced Hyprland window look, the chat AI). Most also expose an `IpcHandler`; so do the panels in `modules/`.
- **`modules/<Feature>/`** holds one feature each. Full-screen panels extend `components/ModalPanel.qml`, and the wallpaper and theme pickers extend `CarouselPanel.qml`. Most panels are only built while open: `shell.qml` instantiates their `*Module.qml`, which holds the panel's `IpcHandler` and a `LazyLoader`. So a closed panel's IPC calls must not need the panel, and anything a panel keeps between openings goes in its State or a service. Bar widgets live in `modules/Bar/Widgets/`, are registered by id in `modules/Bar/BarWidgets.qml`, and are placed from `Settings.layout` through `WidgetZone` / `WidgetSlot`.
- **`scripts/`** holds Python helpers the QML runs through `Process` (wallpaper apply, screenshots, the lock-key watcher, the Hyprland shortcuts parser, the TUI window launcher, the chat AI). User text goes to scripts as arguments, never spliced into a shell string.
- **`matugen/`**: `quickshell.toml` is a self-contained matugen config (template paths are relative to the file) run by `services/Matugen.qml`. It themes the shell itself (`config/GeneratedColors.json`) and also Hyprland, Zen, alacritty, GTK, Qt and starship. Those outputs land in `~/.config/...` from templates stored here, so edit the template here, not the generated file.

## Conventions

- **Visible text:** every string goes through `I18n.tr("dotted.key", args...)`. Add the key to all three dictionaries in `config/Translations.qml` (en, fr, es); `{0}` / `{1}` are the placeholders.
- **Git-ignored runtime state:** `config/*.json` files (Settings, UserDefaults, ThemeState, LocaleState, LauncherState, ChatAiState, GeneratedColors, NotificationActions). Back up `Settings.json` before anything that resets or bulk-changes settings.
- **Outside the project:** ask before editing the user's dotfiles (`~/.config/hypr` and the like); suggest the change instead.
- **Hyprland:** dynamic rules set via `hyprctl keyword` are wiped when Hyprland reloads its config (matugen triggers a reload shortly after login). Reapply them on `Hyprland.rawEvent` `configreloaded`. Layer-rule namespace matches are regexes, so anchor them with `^...$`.
- **Comments:** comments explain what an item is for, in full sentences, above properties and functions. Match that density.
- **Commit messages:** a single imperative sentence describing the user-visible change, with no type prefix (e.g. "Add tabs to the launcher: all, applications, files and the web"). Features are built on a branch and merged into master with `Merge <branch>: <what it does>`.
