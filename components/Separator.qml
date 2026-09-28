import QtQuick
import qs.config

// Thin divider between widgets sharing a pill: upright, or lying across a
// side bar.
Rectangle {
  implicitWidth: Theme.barVertical ? Math.round(Theme.barHeight * 0.5) : 1
  implicitHeight: Theme.barVertical ? 1 : Math.round(Theme.barHeight * 0.5)
  color: Theme.separatorColor
}
