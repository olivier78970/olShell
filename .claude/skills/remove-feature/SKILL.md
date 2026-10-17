---
name: remove-feature
description: Remove a feature from olShell completely - a setting, a bar widget, a panel or a service, or a whole branch of work to throw away - from the code, the translations, the docs and the runtime state, and prove nothing is left. Use it whenever the user asks to remove, delete, drop, revert or "forget" a feature or setting, or to undo a change that touched several files, even if they don't say "remove the feature".
---

# Removing a feature from olShell

It is the reverse of the `add-setting`, `add-panel`, `add-bar-widget` and `add-service` skills: whatever place those list for adding, the feature has to leave. A leftover doesn't fail loudly (a dead translation key, a row in the docs, a key in `Settings.json`), so finish with the leftovers script, which must come back empty.

## Decide how

- **Uncommitted work, or a branch not merged**: don't edit file by file. `git checkout -- <paths>` for the files that hold only this feature, then read the diff of the rest and take the feature out by hand (a file may also hold work to keep: a `CLAUDE.md` edit, another setting). A branch that holds nothing else is deleted: `git switch master && git branch -d <name>`.
- **Merged work**: take it out by hand, on a branch if it touches three files or more (CLAUDE.md, Branches).
- **Never `git checkout --`, `git stash` or `rm` runtime state** (`config/*.json`): it is the user's. A running checkout shell also reloads on every file change, so check `shell.sh status` first, and `shell.sh backup` before touching anything under `config/`.

## The places to take it out of

Mirror the add skills; for each name the feature introduced (setting keys, widget id, State, IPC target, translation keys), look in:

1. **`config/Defaults.qml`, `config/Settings.qml`** (limits, choices, the property, the `valid()` branch, the JsonAdapter property), `config/Theme.qml`.
2. **`modules/Settings/SettingsPages.qml`** (the row, and a category or tab if it was the last one in it), `SettingsPanel.qml` (options, values, `rowEnabled`, `disabledReasonOf`), `SettingsModule.qml` (the IPC comments, `choose()`'s `allowed`).
3. **A widget**: its file, `BarWidgets.qml`, `Settings.widgetIds`, the default layout, the layout editor's icon. **A panel**: its State, Module, `Panels.all`, `shell.qml`, its placement setting. **A service**: the file, its startup reference in `shell.qml`, its IPC target.
4. **Translations**: each key in en, fr and es. `.claude/scripts/check-translations.py` flags a key that is used but missing, not one that is unused, so the leftovers script is what finds them.
5. **Docs**: the Settings table row in `docs/settings.md`, the IPC list in `docs/ipc.md`, the feature's section, `README.md`. Find the lines with `grep -n '<name>' docs/*.md | cut -c1-200`; many are thousands of characters long.
6. **`docs/structure.md`**: rerun `.claude/scripts/structure.py` after removing a file.

## The runtime state

- **`config/Settings.json`**: the shell rewrites it on its next save and drops a key it no longer knows, so a removed setting disappears by itself once any setting is changed. If it must go now, back up first and remove the key with a JSON edit (never a wholesale rewrite).
- **`config/Profiles.json`**: a saved profile may hold the key. It is harmless (a restore skips keys that have no default) and the profiles are the user's, so leave it, and tell the user.

## Prove it

```sh
.claude/skills/remove-feature/scripts/find-leftovers.sh <name> [<name>...]
.claude/scripts/check-all.sh
```

Give the script every name: the setting keys, the translation keys (`settings.<key>`), the IPC function names, the widget id and its file name. It prints nothing but "no leftovers" when the feature is gone; a hit in `config/*.json` is runtime state, handled as above. Then test with the `test-deploy` skill (`shell.sh errors` prints nothing) and tell the user what was removed and what was left on purpose.
