#!/usr/bin/env bash
# Runs every check a change needs, in one go: the file list, the translations,
# debug logging in the added lines, one check-setting.sh per setting added to
# Defaults.qml, and the checkout shell's errors since its last reload.
# Usage (from the repo root): check-all.sh
# Exits 1 when the file list, the translations or the debug logging fail. A
# setting's MISSING lines and the shell's errors are shown but don't fail it:
# some settings legitimately have no place of their own (see add-setting).
set -u

repo=$(git rev-parse --show-toplevel)
cd "$repo" || exit 1
failed=0

echo "== file list"
.claude/scripts/structure.py --check || failed=1

echo "== translations"
.claude/scripts/check-translations.py || failed=1

echo "== debug logging"
added=$(git diff HEAD --unified=0 -- '*.qml' 2>/dev/null | grep -E '^\+.*console\.log' || true)
if [ -n "$added" ]; then echo "$added"; echo "console.log in the changes: remove it"; failed=1; else echo "none"; fi

# The settings added to Defaults.qml: the keys of the added lines.
keys=$(git diff HEAD --unified=0 -- config/Defaults.qml 2>/dev/null | grep -E '^\+    [A-Za-z0-9]+:' | sed -E 's/^\+ +([A-Za-z0-9]+):.*/\1/')
removed=$(git diff HEAD --unified=0 -- config/Defaults.qml 2>/dev/null | grep -E '^-    [A-Za-z0-9]+:' | sed -E 's/^- +([A-Za-z0-9]+):.*/\1/')
for key in $keys; do
  # A key both removed and added is only changed.
  printf '%s\n' "$removed" | grep -qx "$key" && continue
  echo "== setting $key"
  .claude/skills/add-setting/scripts/check-setting.sh "$key" | grep -E 'MISSING|Setting' || true
done

echo "== checkout shell errors (since its last reload)"
shell=.claude/skills/test-deploy/scripts/shell.sh
if $shell status | grep -q "checkout shell: running"; then
  errors=$($shell errors)
  if [ -n "$errors" ]; then echo "$errors"; else echo "none"; fi
else
  echo "the checkout shell isn't running: not checked"
fi

[ "$failed" = 0 ] && echo "check-all: pass" || echo "check-all: FAILED"
exit "$failed"
