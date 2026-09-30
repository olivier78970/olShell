---
name: test-deploy
description: Run olShell's checkout to test a change live, read its log, and deploy master to the everyday copy in ~/.config/olShell, switching safely between the two shells without losing the user's settings. Use it whenever a change needs trying in the real shell, the user asks to test, run, restart, reload, deploy, install or "put live" the shell, or asks which shell is running, even if they don't name the deployed copy.
---

# Testing and deploying olShell

The user runs a **deployed copy** in `~/.config/olShell` every day, a plain copy of `master`. This checkout is for development. Only one shell may run at a time: two means two bars, and IPC calls reach only one of them. Each copy keeps its own git-ignored settings in `config/*.json`.

Everything goes through the bundled script, run from the repo root:

```sh
S=.claude/skills/test-deploy/scripts/shell.sh
$S status                  # which shell is running
$S dev                     # run the checkout (refuses while the deployed shell runs)
$S dev --stop-deployed     # only once the user has agreed to stop the deployed shell
$S log [lines]             # the checkout shell's log
$S deploy                  # copy master into ~/.config/olShell
$S deployed                # stop the checkout, run the deployed copy again
$S backup                  # copy both shells' config/*.json to ~/.cache/olshell-backups/
```

`dev` and `deploy` back up both shells' settings files first. A test once wiped the user's live settings, so run `backup` yourself before anything else that resets or bulk-changes settings. The script unsets `QS_CONFIG_PATH`, which the running shell exports: with it set, `quickshell list --all` fails, and a bare `qs ipc call` reaches the deployed copy.

## Testing a change

1. `$S status`. If the checkout is already running, use it.
2. If the deployed shell is running, **ask the user** before stopping it, then run `$S dev --stop-deployed`.
3. Quickshell reloads live when a `.qml` file changes. An in-place `sed -i` may not trigger the reload, so `touch shell.qml` afterwards, and check the log shows a reload.
4. Drive the change with IPC (`quickshell -p . ipc call <target> <function> …`), then read `$S log` for `ReferenceError`, `TypeError`, `Unable to assign`, `Cannot` and warnings from the files you changed.
5. Don't take screenshots or send synthetic input. The user looks at the shell themselves, so tell them what to check and where.
6. When done, and unless the user wants to keep testing, `$S deployed` gives them their everyday shell back.

## Deploying

Deploy only when the user asks.

1. `deploy` copies **master**, so the change must be committed and merged first. Feature work happens on a branch, merged into master with a `Merge <branch>: <what it does>` commit. Ask before merging if the user hasn't said to.
2. `$S deploy`. It leaves the deployed copy's settings files alone, and lists files that are in the deployed copy but no longer in master; ask before deleting them.
3. `$S deployed`, which stops the checkout shell and starts the deployed one.
4. The shell points Hyprland's `QS_CONFIG_PATH` at its own folder about a second after it starts. To confirm the shortcuts reach the deployed copy:
   ```sh
   hyprctl eval "hl.exec_cmd(\"sh -c 'env | grep QS_ > /tmp/qs-env'\")"; cat /tmp/qs-env
   ```
