---
name: add-setting
description: Add a new user setting to olShell (or give a feature an adjustable option) and wire it through every place a setting lives - Defaults, Settings (limits/choices, property, file adapter), Theme, the settings page row, the settings IPC, en/fr/es translations and the README. Use it whenever the user asks for a new setting, option, toggle, slider or choice in the settings panel, asks to make a hard-coded value configurable, or builds a feature that "comes with a setting", even if they don't say "add a setting".
---

# Adding a setting to olShell

CLAUDE.md gives the general flow (Defaults → Settings → Theme, translations, the Settings table in docs/settings.md). This skill covers the places it leaves out. If one is forgotten, nothing fails loudly: the value just doesn't save, doesn't reset with its category, or is missing from the IPC documentation. Copy the shape of a neighbouring setting of the same kind (`launcherHistory` for a slider, `lockStayAwakeFullscreen` for a check box, `weatherUnit` for a choice, `weatherLocation` for text).

## The places CLAUDE.md doesn't mention

- **`config/Settings.qml` → the `JsonAdapter`** near the bottom: `property <type> key: Defaults.values.key`. Without it the value is never saved to or read from `Settings.json`.
- **`config/Settings.qml` → `valid()`**, only when the generic checks don't fit:
  - Integers round by default. A fractional value (a 0–1 opacity, a duration in tenths) goes in one of the rounding lists at the end of `valid()`.
  - Free text needs a branch of its own (see `weatherLocation`).
- **The row goes in `modules/Settings/SettingsPages.qml`** (`rows`), not `SettingsPanel.qml`. Its `category` is a page id from `categories` (a category, or a tab of one). The row is also what puts the key in its category's **Reset** and profiles (`keysOf()`), so every setting needs one.
  - For a check box, use a `toggles` row with `checkBoxes: true`. The row gets its own key (`<key>Row`), and the toggle inside it names the setting.
- **`modules/Settings/SettingsPanel.qml`**, only for `buttons` / `dropdown` rows: add a `<key>Options` property mapping each choice to `I18n.tr("settings.<key>.<value>")`, and a line in `optionsOf(row)`.
- **Translations for a choice**: besides the `settings.<key>` label, add one `settings.<key>.<value>` for each value, in en, fr and es. Make the French and Spanish words agree in gender and number with their noun.
- **`modules/Settings/SettingsModule.qml`** (the `settings` IpcHandler):
  - `set()` and `choose()` already accept any key with a default. Their comments, which list the keys, are the IPC documentation, so add the key there: numbers and yes/no settings in `set`'s comment, choices and text in `choose`'s.
  - A text setting also needs allowing in `choose()`'s `allowed` expression.
- **`docs/settings.md`**: the Settings table row. The **From a script** section lists no keys: `settings map` gives every setting's page, kind, range and choices, so the key shows there on its own once it has a row. Also update the feature's own section if it describes the behaviour the setting changes.
  - `docs/settings.md` is 36 KB, and many paragraphs are one line of several thousand characters. Don't read it whole, and don't let a search print whole lines. Find what you need with `grep -n '<pattern>' docs/*.md | cut -c1-200`, then `Read` only those lines (`offset`/`limit`) before editing them.
- **Settings applied once** (a Hyprland keyword, a process, a file): apply at startup and on change, not only through a binding.

## Check nothing was missed

From the repo root:

```sh
.claude/skills/add-setting/scripts/check-setting.sh <key> [slider|toggle|choice|text] [visual]
```

Fix every `MISSING` line, and run `.claude/scripts/check-translations.py` (the same keys and placeholders in en, fr and es). Then check by hand what the scripts can't: the Settings table row in docs/settings.md, and real French and Spanish wording.

## Testing over IPC

With the checkout shell running (the `test-deploy` skill starts it and backs up the settings):

```sh
quickshell -p . ipc call settings set <key> <value>     # numbers, 1/0
quickshell -p . ipc call settings choose <key> <value>  # choices, text
quickshell -p . ipc call settings get <key>             # or getChoice
quickshell -p . ipc call settings resetPage <category>
```

- Try an out-of-range or invalid value, and confirm it is clamped or ignored.
- Check that `config/Settings.json` now holds the key and that the log has no QML errors.
- Tell the user where the row is so they can look at it themselves.
