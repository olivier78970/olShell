---
name: ship
description: Commit olShell's work the project's way - a branch, a one-sentence commit, a merge commit into master, a push, and optionally the deploy to ~/.config/olShell. Use it whenever the user says commit, push, merge, ship, release or deploy, alone or together ("commit push and deploy"), and not before they ask.
---

# Committing, merging, pushing and deploying

Only when the user asks, and only the steps they named. A request for "commit" is not one for "push" or "deploy".

## Commit and merge

1. `git status --short`, and `git diff --stat` for what is in. Remove any debug logging first (`grep -rn 'console.log' --include='*.qml' .` for the lines you added).
2. Run the checks that apply: `.claude/scripts/check-translations.py`, `.claude/scripts/structure.py --check` (rerun it without `--check` if files were added, moved or removed), and the `check-*.sh` of the skill the change followed.
3. Work happens on a feature branch (`git checkout -b <short-name>`; on master, branch before committing).
4. Commit with a single imperative sentence describing the user-visible change, no type prefix (`Add tabs to the launcher: all, applications, files and the web`), then the attribution line the session's system reminder gives.
5. Merge into master with `git merge --no-ff <branch> -m "Merge <branch>: <what it does>"` (plus the attribution line), from master.

## Push

`git push origin master`, after the merge. The branch itself isn't pushed unless asked.

## Deploy

Deploy only when asked, with the `test-deploy` skill's script, in this order:

1. The change must be merged into master (`deploy` copies master, not the working tree).
2. `shell.sh deploy`, then `shell.sh deployed`. `deployed` stops the checkout shell and waits until it is gone before starting the deployed one; starting it while the checkout still runs leaves the deployed shell without its notification and polkit D-Bus names, and it has to be restarted.
3. Check `shell.sh status` shows only the deployed shell, and the log has no `WARN` about registering.
4. The deploy lists files still in the deployed copy that master no longer has (a moved or removed file): report them, and delete only if the user agrees.

## Report

Say what was committed (hashes), what was pushed, and what was deployed or left; say so plainly if something wasn't tested.
