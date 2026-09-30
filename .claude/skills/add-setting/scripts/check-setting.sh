#!/usr/bin/env bash
# Reports which of the places a setting must appear in mention its key.
# Usage (from the repo root): check-setting.sh <key> [slider|toggle|choice|text] [visual]
set -u

key=${1:?usage: check-setting.sh <key> [slider|toggle|choice|text] [visual]}
kind=${2:-}
visual=${3:-}
missing=0

# Prints OK or MISSING for one place: a label, then a grep -E pattern and a file.
check() {
  local label=$1 pattern=$2 file=$3 count
  count=$(grep -cE -- "$pattern" "$file" 2>/dev/null)
  if [ "${count:-0}" -gt 0 ]; then
    printf '  OK       %s\n' "$label"
  else
    printf '  MISSING  %s\n' "$label"
    missing=$((missing + 1))
  fi
}

# Prints the same, for a place that only some kinds of settings need.
optional() {
  local label=$1 pattern=$2 file=$3
  if grep -qE -- "$pattern" "$file" 2>/dev/null; then
    printf '  OK       %s\n' "$label"
  else
    printf '  --       %s (only if it applies)\n' "$label"
  fi
}

echo "Setting '$key':"
check "Defaults.qml values" "^\s*$key:" config/Defaults.qml
check "Settings.qml property" "readonly property \S+ $key: root.valid\(\"$key\"" config/Settings.qml
check "Settings.qml JsonAdapter" "property \S+ $key: Defaults.values.$key\b" config/Settings.qml

case $kind in
  slider) check "Settings.qml limits" "^\s*$key: \[" config/Settings.qml ;;
  choice) check "Settings.qml choices" "^\s*$key: " config/Settings.qml
          check "SettingsPanel.qml optionsOf" "row.key === \"$key\"" modules/Settings/SettingsPanel.qml ;;
  text)   check "Settings.qml valid() branch" "key === \"$key\"" config/Settings.qml
          check "SettingsModule.qml choose() allowed" "key === \"$key\"" modules/Settings/SettingsModule.qml ;;
  *)      optional "Settings.qml limits/choices" "^\s*$key: \[" config/Settings.qml ;;
esac

if [ -n "$visual" ]; then
  check "Theme.qml" "Settings\.$key\b" config/Theme.qml
else
  optional "Theme.qml (visual settings)" "Settings\.$key\b" config/Theme.qml
fi

check "SettingsPages.qml row or toggle" "key: \"$key\"" modules/Settings/SettingsPages.qml
check "SettingsModule.qml IPC comment" "\b$key\b" modules/Settings/SettingsModule.qml

# Its label must be in each of the three dictionaries (en, fr, es): the text
# keys on its row's line in SettingsPages.qml (a check box in a grouped row
# has its own), else settings.<key>.
texts=$(grep -E "key: \"$key\"" modules/Settings/SettingsPages.qml | grep -oE 'I18n\.tr\("[^"]+"' | sed 's/I18n\.tr("//; s/"$//' | sort -u)
[ -n "$texts" ] || texts="settings.$key"
for text in $texts; do
  labels=$(grep -cE "^\s*\"${text//./\\.}\":" config/Translations.qml)
  if [ "${labels:-0}" -ge 3 ]; then
    printf '  OK       Translations %s x%s\n' "$text" "$labels"
  else
    printf '  MISSING  Translations %s (found %s of 3: en, fr, es)\n' "$text" "${labels:-0}"
    missing=$((missing + 1))
  fi
done

check "README 'From a script' section" "\`$key\`" README.md

# Any use outside config/ and modules/Settings/: the feature reading it.
uses=$(grep -rlE "(Settings|Theme)\.$key\b" --include='*.qml' . | grep -vE '^\./(config|modules/Settings)/' | head -5)
if [ -n "$uses" ]; then
  printf '  OK       used by: %s\n' "$(echo "$uses" | tr '\n' ' ')"
else
  printf '  --       no feature reads Settings.%s / Theme.%s outside config/ and modules/Settings/\n' "$key" "$key"
fi

echo "Also check by hand: the README Settings table row, and fr/es label text being real translations."
[ "$missing" -eq 0 ]
