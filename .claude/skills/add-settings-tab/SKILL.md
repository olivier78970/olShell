---
name: add-settings-tab
description: Add a tab to a category of olShell's settings panel, split a category or tab into several tabs, or move rows from one tab to another (like the Theme, OSD, Panels, Bar widgets and Chat AI tabs) and update every place a settings page id is listed - SettingsPages categories and rows, the saveDefaults list in the settings IPC, tab names, the README's categories and Settings table. Use it whenever the user wants settings regrouped, a section turned into its own tab, or a new tab in the settings, even if they don't say "tab".
---

# Adding or splitting a settings tab

A category in `modules/Settings/SettingsPages.qml` (`categories`) is either a single page, or has `tabs`, each tab a page of rows of its own. A page's id is the string the rows name in `category:`. Page ids are also what **save as my defaults / restore** and the IPC's `saveDefaults` / `restoreDefaults` take, so a renamed or moved page touches more than the page list. The values themselves are stored per key, so moving rows between pages never loses a saved setting.

## The places to edit

1. **`SettingsPages.qml` → `categories`**: add the `{ id, label: I18n.tr(...) }` to the category's `tabs` (turning a plain category into one with `tabs` if it had none: the first tab keeps the old id, so its rows and saved defaults stay valid). Keep the comment above the category saying how its tabs are arranged.
   - Page ids must be unique among all pages (`pages` is built from them). `clockPanel` is the Panels category's Clock tab, so a bar widget's one is `widgetClock`.
2. **`SettingsPages.qml` → `rows`**: change each moved row's `category:` to the new page id. Drop a row's `title:` when its tab is now named the same, since the title only heads a section inside a page.
3. **Tab label**: reuse an existing `settings.*` key when the name already exists (a section title, a widget name); otherwise add one to en, fr and es in `config/Translations.qml`. Delete a key nothing uses any more (`grep -rn '"<key>"'`).
4. **`modules/Settings/SettingsModule.qml`**: the `saveDefaults` comment lists the page ids; keep it in step with `pages`.
5. **`README.md`** (search with `grep -n … | cut -c1-200`; its lines are very long):
   - the **Categories** line of the `saveDefaults` / `restoreDefaults` description lists every page id with its tab name;
   - the Settings table's first column says where a setting is (`Bar widgets (Clock tab)`): update the rows of every moved setting.
6. **Other mentions**: `grep -rn '<old page id>'` across `modules`, `config`, `README.md` and `.claude/skills` (the `add-bar-widget` skill says where a widget's settings go).

## Check

```sh
.claude/scripts/check-translations.py
.claude/skills/add-setting/scripts/check-setting.sh <key of a moved row> <slider|toggle|choice|text>
grep -rn '<old page id>' modules config README.md .claude   # nothing left
```

## Test

With the checkout shell running (the `test-deploy` skill; `restart` for a fresh start): open the settings over IPC, go to the category and tell the user which tabs to look at and what each should hold. Read the log for QML errors. Never take screenshots.
