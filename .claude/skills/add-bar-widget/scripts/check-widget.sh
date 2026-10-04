#!/usr/bin/env bash
# Checks that a bar widget is wired everywhere a widget id is listed, and that
# every registered widget is.
# Usage (from the repo root): check-widget.sh <id> <Component>
#   e.g. check-widget.sh chatAi ChatAiTrigger
set -u

id=${1:?usage: check-widget.sh <id> <Component>}
component=${2:?usage: check-widget.sh <id> <Component>}
missing=0

# Prints OK or MISSING for one place: a label, then a grep -E pattern and a file.
check() {
  local label=$1 pattern=$2 file=$3
  if grep -qE -- "$pattern" "$file" 2>/dev/null; then
    printf '  OK       %s\n' "$label"
  else
    printf '  MISSING  %s\n' "$label"
    missing=$((missing + 1))
  fi
}

echo "Widget '$id' ($component):"
check "modules/Bar/Widgets/$component.qml" "." "modules/Bar/Widgets/$component.qml"
check "BarWidgets.qml components map" "^\s*$id: $id,?$" modules/Bar/BarWidgets.qml
check "BarWidgets.qml Component" "Component \{ id: $id; $component \{\} \}" modules/Bar/BarWidgets.qml
check "Settings.qml widgetIds" "widgetIds: \[.*\"$id\"" config/Settings.qml
check "BarLayoutEditor.qml icon" "\b$id: \"" modules/Settings/BarLayoutEditor.qml
check "SettingsModule.qml place() widget list" "\b$id\b" modules/Settings/SettingsModule.qml
check "docs/structure.md lists $component (run .claude/scripts/structure.py)" "\b$component\b" docs/structure.md

labels=$(grep -cE "^\s*\"settings\.widget\.$id\":" config/Translations.qml)
if [ "${labels:-0}" -ge 3 ]; then
  printf '  OK       settings.widget.%s x%s\n' "$id" "$labels"
else
  printf '  MISSING  settings.widget.%s (found %s of 3: en, fr, es)\n' "$id" "${labels:-0}"
  missing=$((missing + 1))
fi

# Where it starts: a zone of the default layout, or off.
zone=$(grep -E "^\s*bar(Left|Center|Right): \[.*\"$id\"" config/Defaults.qml | sed -E 's/^\s*(bar[A-Za-z]+):.*/\1/')
printf '  --       default place: %s\n' "${zone:-off (in no default zone)}"

# Every id in widgetIds must have its component and its layout-editor icon.
ids=$(grep -oE 'widgetIds: \[[^]]*\]' config/Settings.qml | grep -oE '"[A-Za-z]+"' | tr -d '"')
for other in $ids; do
  grep -qE "^\s*$other: $other,?$" modules/Bar/BarWidgets.qml || { printf '  MISSING  %s: in widgetIds but not in BarWidgets.qml\n' "$other"; missing=$((missing + 1)); }
  grep -qE "\b$other: \"" modules/Settings/BarLayoutEditor.qml || { printf '  MISSING  %s: no BarLayoutEditor icon\n' "$other"; missing=$((missing + 1)); }
done

echo "Also check by hand: the Layout paragraph's widget names in docs/settings.md, and the widget on a left/right bar (BarStack)."
[ "$missing" -eq 0 ]
