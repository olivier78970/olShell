#!/usr/bin/env bash
# Checks the wiring of a full-screen panel, and that every panel State is in
# Panels.all and opens through Panels.open().
# Usage (from the repo root): check-panel.sh <State> <id> <ipc target>
#   e.g. check-panel.sh ChatAiState chatAi chatai
set -u

state=${1:?usage: check-panel.sh <State> <id> <ipc target>}
id=${2:?usage: check-panel.sh <State> <id> <ipc target>}
target=${3:?usage: check-panel.sh <State> <id> <ipc target>}
missing=0

# Prints OK or MISSING for one place: a label, then a grep -E pattern and files.
check() {
  local label=$1 pattern=$2; shift 2
  if grep -qE -- "$pattern" "$@" 2>/dev/null; then
    printf '  OK       %s\n' "$label"
  else
    printf '  MISSING  %s\n' "$label"
    missing=$((missing + 1))
  fi
}

echo "Panel $state ($id, IPC target '$target'):"
check "config/$state.qml with toggle()" "function toggle" "config/$state.qml"

# The panel States are the ones with a toggle(); each must be in Panels.all
# and open through Panels.open(), which closes the others.
panels=$(grep -l 'function toggle' config/*State.qml | xargs -n1 basename | sed 's/\.qml$//')
for panel in $panels; do
  if ! grep -qE "\b$panel\b" config/Panels.qml; then
    printf '  MISSING  %s is not in Panels.all (config/Panels.qml)\n' "$panel"
    missing=$((missing + 1))
  fi
  if ! grep -qE "Panels\.open\(" "config/$panel.qml"; then
    printf '  MISSING  %s does not open through Panels.open()\n' "$panel"
    missing=$((missing + 1))
  fi
done
[ "$missing" -eq 0 ] && printf '  OK       the %s panel States are in Panels.all and open through Panels.open()\n' "$(echo "$panels" | wc -l)"

module=$(grep -lE "IpcHandler" modules/*/*Module.qml 2>/dev/null | xargs grep -lE "\b$state\b" 2>/dev/null | head -1)
if [ -n "$module" ]; then
  printf '  OK       module: %s\n' "$module"
  check "  its IpcHandler target \"$target\"" "target: \"$target\"" "$module"
  check "  its LazyLoader" "LazyLoader" "$module"
  check "shell.qml instantiates $(basename "$module" .qml)" "^\s*$(basename "$module" .qml) \{" shell.qml
else
  printf '  MISSING  a modules/*/*Module.qml with an IpcHandler using %s\n' "$state"
  missing=$((missing + 1))
fi

check "Defaults.qml ${id}Placement" "^\s*${id}Placement:" config/Defaults.qml
check "Settings.qml choices.${id}Placement" "^\s*${id}Placement: root\.panelPlacements" config/Settings.qml
check "Settings.qml placementKeys" "placementKeys: \[.*\"${id}Placement\"" config/Settings.qml
check "Settings.qml property" "readonly property string ${id}Placement: root\.valid" config/Settings.qml
check "Settings.qml JsonAdapter" "property string ${id}Placement: Defaults\.values\.${id}Placement" config/Settings.qml
check "SettingsPages.qml Placement row" "key: \"${id}Placement\", category: \"panels\"" modules/Settings/SettingsPages.qml
check "the panel uses Settings.${id}Placement" "placement: Settings\.${id}Placement" modules/*/*.qml
check "SettingsModule.qml choose() comment" "\b${id}Placement\b" modules/Settings/SettingsModule.qml

labels=$(grep -cE "^\s*\"settings\.placement\.$id\":" config/Translations.qml)
if [ "${labels:-0}" -ge 3 ]; then
  printf '  OK       settings.placement.%s x%s\n' "$id" "$labels"
else
  printf '  MISSING  settings.placement.%s (found %s of 3: en, fr, es)\n' "$id" "${labels:-0}"
  missing=$((missing + 1))
fi

check "README IPC block: ipc call $target toggle" "ipc call $target toggle" README.md
check "README choices table: ${id}Placement" "\`${id}Placement\`" README.md
check "README Structure tree: $state.qml" "$state\.qml" README.md

echo "Also check by hand: the Placement table row in README, and a keybinding suggestion (ask before editing ~/.config/hypr)."
[ "$missing" -eq 0 ]
