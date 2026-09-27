import QtQuick
import qs.config

// A small link button put after a setting's name, for a value that can
// follow one of the shell's instead of its own (e.g. Hyprland's border width
// following the shell's): filled in the accent color while it follows. The
// owner gives `on` and reacts to `toggled`; `hovered` lets it show what the
// button follows in a tooltip.
Rectangle {
  id: root

  property bool on: false
  readonly property bool hovered: area.containsMouse

  signal toggled()

  implicitWidth: content.implicitWidth + 14
  implicitHeight: content.implicitHeight + 6
  radius: Theme.radiusFor(height)
  color: root.on ? Theme.accentColor
    : area.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
  border.color: root.on ? Theme.accentColor : Theme.outlineColor
  border.width: 1

  // A link (nf-md-link).
  ThemedText {
    id: content
    anchors.centerIn: parent
    text: "󰌷"
    color: root.on ? Theme.backgroundColor : Theme.accentColor
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
