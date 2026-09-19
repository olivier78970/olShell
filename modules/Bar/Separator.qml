import QtQuick
import qs.config

// Thin vertical divider between widgets sharing a pill.
Rectangle {
  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: 1
  implicitHeight: Math.round(Theme.barHeight * 0.5)
  color: Theme.separatorColor
}
