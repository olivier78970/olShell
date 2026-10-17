---
name: debug-qml
description: Find why an olShell change misbehaves at runtime - a QML error that doesn't show at load, a binding that gives undefined, an item with the wrong size, a Hyprland rule that vanishes, a setting that doesn't save or apply - starting from the shell's log. Use it whenever something in the shell doesn't work as expected, logs a warning, or a feature works at first and then stops, even if the user doesn't say "debug".
---

# Debugging the shell at runtime

QML checks very little when a file loads: a wrong name, a missing import or a bad binding only fails when that code runs, and then as one line in the log. So start from the log, not from the code.

## The loop

1. `shell.sh status`, then the checkout shell running (`test-deploy` skill).
2. Reproduce the problem over IPC (`shell.sh ipc <target> <function>`), not with the mouse or screenshots.
3. `shell.sh errors`: the `ReferenceError`, `TypeError`, `Unable to assign` and `Cannot` lines since the last reload. Nothing printed means the log has no error; the cause is then in the logic or in state.
4. Read the file and line the error names (`@modules/Foo.qml[51:5]`), and what the property it assigns is bound to.
5. Fix, and watch that the shell reloaded (`shell.sh log 20` shows "Reloading configuration"). A fix that doesn't reload: `touch shell.qml` (a `sed -i` doesn't always trigger it). Rerun `errors`. Don't edit while a `restart` is running.

## What the errors usually mean

- **`ReferenceError: X is not defined`** in a `config/` file for a name from `services/`: `config/` doesn't import `qs.services`. Move the logic into `config/` and let the service read it. In any other file, a missing `import qs.<dir>`.
- **`Unable to assign [undefined] to ...`** right after something was hidden, disabled or switched: a binding was evaluated while its item was being destroyed. Harmless if it appears once at teardown; a real bug if it repeats while the item is alive (a property read from an item that isn't there yet, or `null`).
- **`TypeError: Property 'x' of object ... is not a function`**: the code calls something that is a property or doesn't exist on that singleton; check the name in the service.
- **An item with the wrong size or place after a setting changed**: anchors that flip with a setting leave a stale size. Bind `x`, `y`, `width` and `height` instead of switching anchors to `undefined`.
- **A Hyprland rule that works, then stops**: the config was reloaded (matugen does it shortly after login) and wiped the rules set with `hyprctl keyword`. Reapply on `Hyprland.rawEvent` `configreloaded`. A layer rule matching too many windows: namespace and class patterns are regexes, so anchor them with `^...$`.
- **A setting that doesn't save, doesn't reset or isn't in a profile**: its key is missing from the JsonAdapter in `Settings.qml`, or it has no row (`add-setting` skill, `check-setting.sh <key>`).
- **A panel that opens in the wrong place or on the wrong monitor**: `multi-monitor` skill.
- **IPC call "target not found"**: the service or module that owns the target isn't instantiated yet (a closed panel's calls must not need the panel; a service with a target needs its startup reference in `shell.qml`).
- **The change isn't in the running shell**: the deployed copy runs, not the checkout (`shell.sh status`).

## Before saying it works

`shell.sh errors` prints nothing, the IPC calls give the expected values, and the user has been told what to look at and where.
