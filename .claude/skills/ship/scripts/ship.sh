#!/usr/bin/env bash
# Ships the current feature branch the project's way, one step at a time as
# the user asked for them: checks, a one-sentence commit, a merge commit into
# master, and optionally the push and the deploy. Run from the repo root, on
# the feature branch with the work uncommitted (or already committed).
#   ship.sh --check                         only the checks
#   ship.sh -c "<commit sentence>" -m "<what it does>" [-t "<trailer>"] [--push] [--deploy]
# -c is the commit's single imperative sentence; -m completes "Merge <branch>: ";
# -t is the attribution line the session's system reminder gives (added to both
# messages). Without --push nothing is pushed, without --deploy nothing is
# deployed: pass only what the user named.
set -u

repo=$(git rev-parse --show-toplevel)
cd "$repo" || exit 1
shell=.claude/skills/test-deploy/scripts/shell.sh
branch=$(git branch --show-current)
commit="" what="" trailer="" push=0 deploy=0 only_check=0

while [ $# -gt 0 ]; do
  case $1 in
    -c) commit=$2; shift ;;
    -m) what=$2; shift ;;
    -t) trailer=$2; shift ;;
    --push) push=1 ;;
    --deploy) deploy=1 ;;
    --check) only_check=1 ;;
    *) sed -n '2,11p' "$0"; exit 1 ;;
  esac
  shift
done

fail() { echo "ship: $*" >&2; exit 1; }

# The checks: debug logging in what is added, the translations, the file list.
checks() {
  local added
  added=$(git diff HEAD --unified=0 -- '*.qml' 2>/dev/null | grep -E '^\+.*console\.log' || true)
  [ -z "$added" ] || { echo "$added"; fail "console.log in the changes: remove it first"; }
  .claude/scripts/check-translations.py || fail "translations"
  .claude/scripts/structure.py --check || fail "docs/structure.md is out of date: run .claude/scripts/structure.py"
}

checks
[ "$only_check" = 1 ] && { echo "ship: checks pass"; exit 0; }

[ "$branch" != master ] || fail "on master: switch to the feature branch first (git checkout -b <name>)"
[ -n "$what" ] || fail "-m \"<what it does>\" is required"
message() { if [ -n "$trailer" ]; then printf '%s\n\n%s' "$1" "$trailer"; else printf '%s' "$1"; fi; }

if [ -n "$(git status --porcelain)" ]; then
  [ -n "$commit" ] || fail "uncommitted changes: -c \"<commit sentence>\" is required"
  git add -A && git commit -q -m "$(message "$commit")" || fail "commit"
fi
git checkout -q master || fail "checkout master"
git merge --no-ff "$branch" -m "$(message "Merge $branch: $what")" | tail -1 || fail "merge"
[ -z "$(git status --porcelain)" ] || fail "master isn't clean after the merge"
echo "ship: merged $branch into master ($(git log -1 --format=%h))"

if [ "$push" = 1 ]; then
  git push origin master 2>&1 | tail -2
fi

if [ "$deploy" = 1 ]; then
  $shell deploy 2>&1 | tail -4
  # Switches from the checkout shell if it runs (never both at once); with only
  # the deployed shell running, the deploy reloads it by itself.
  $shell deployed
  $shell status
  [ "$($shell status | grep -c 'running (')" -le 1 ] || fail "both shells are running"
fi
