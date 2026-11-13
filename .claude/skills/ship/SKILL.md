---
name: ship
description: Commit olShell's work the project's way - a branch, a one-sentence commit, a merge commit into master, a push, and optionally the deploy to ~/.config/olShell. Use it whenever the user says commit, push, merge, ship, release or deploy, alone or together ("commit push and deploy"), and not before they ask.
---

# Committing, merging, pushing and deploying

Only when the user asks, and only the steps they named. A request for "commit" is not one for "push" or "deploy".

## The script

`.claude/skills/ship/scripts/ship.sh` does the steps below in order, stopping at the first problem, and only the ones its flags name:

```sh
.claude/skills/ship/scripts/ship.sh --check        # only the checks
.claude/skills/ship/scripts/ship.sh -c "<commit sentence>" -m "<what it does>" -t "<attribution line>" [--push] [--deploy]
```

`-c` is the commit's one imperative sentence, `-m` finishes `Merge <branch>: `, `-t` is the attribution line the session's system reminder gives (it goes on both messages). It must be run on the feature branch, and refuses on master, with `console.log` in the changes, with translations out of step, or with `docs/structure.md` out of date. Only add `--push` or `--deploy` when the user said so. After `--deploy`, tell the user which shell runs (the script fails if both do) and what was backed up. Stop a stray shell by its pid, never with `pkill -f`.

## Commit and merge

1. `git status --short`, and `git diff --stat` for what is in. Remove any debug logging first (`grep -rn 'console.log' --include='*.qml' .` for the lines you added).
2. Run `.claude/scripts/check-all.sh` (rerun `.claude/scripts/structure.py` first if files were added, moved or removed).
3. Work happens on a feature branch (`git checkout -b <short-name>`; on master, branch before committing).
4. Commit with a single imperative sentence describing the user-visible change, no type prefix (`Add tabs to the launcher: all, applications, files and the web`), then the attribution line the session's system reminder gives.
5. Merge into master with `git merge --no-ff <branch> -m "Merge <branch>: <what it does>"` (plus the attribution line), from master.

## Push

`git push origin master`, after the merge. The branch itself isn't pushed unless asked.

GitHub's push protection refuses a push holding something that looks like a secret (`GH013`), such as a CLI's public OAuth client id and secret in a usage script; each finding gives its own `unblock-secret` URL, and a second finding may only show once the first is allowed. Give the user the URLs, with whether the value is really public: when it is, they allow it there and you push again (the commits stay as they are); when it isn't, it comes out of the commit before anything is pushed. `ship.sh` prints these URLs, still deploys, and ends in failure.

## Deploy

Deploy only when asked, with the `test-deploy` skill's script, in this order:

1. The change must be merged into master (`deploy` copies master, not the working tree).
2. `shell.sh deploy`, then `shell.sh deployed`. `deployed` stops the checkout shell and waits until it is gone before starting the deployed one; starting it while the checkout still runs leaves the deployed shell without its notification and polkit D-Bus names, and it has to be restarted.
3. Check `shell.sh status` shows only the deployed shell, and the log has no `WARN` about registering.
4. The deploy lists files still in the deployed copy that master no longer has (a moved or removed file): report them, and delete only if the user agrees.

## Report

Say what was committed (hashes), what was pushed, and what was deployed or left; say so plainly if something wasn't tested.
