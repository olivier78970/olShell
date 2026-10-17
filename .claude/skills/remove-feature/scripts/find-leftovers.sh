#!/usr/bin/env bash
# Lists every remaining mention of the names of a removed feature: in the
# tracked files (code, translations, docs) and in the git-ignored runtime
# state (config/*.json). Prints nothing and exits 0 when none is left.
# Usage (from the repo root): find-leftovers.sh <name>...
#   e.g. find-leftovers.sh barHiddenMonitors barOn settings.monitors.barShown
set -u

[ $# -gt 0 ] || { sed -n '2,6p' "$0"; exit 1; }
repo=$(git rev-parse --show-toplevel)
cd "$repo" || exit 1
found=0

for name in "$@"; do
  # Tracked files; long doc lines are cut so the output stays readable.
  hits=$(git grep -nF -- "$name" | cut -c1-180)
  # The runtime state the shell writes itself, which git doesn't track.
  state=$(grep -nF -- "\"$name\"" config/*.json 2>/dev/null | cut -c1-180)
  if [ -n "$hits$state" ]; then
    found=1
    echo "== $name"
    [ -z "$hits" ] || echo "$hits"
    [ -z "$state" ] || echo "$state  (runtime state: see the skill before editing)"
  fi
done

[ "$found" = 0 ] && echo "no leftovers" >&2
exit "$found"
