import QtQuick
import qs.config

// A small screen with a block where something is placed on it, for a position
// such as "top-right", "center-left" or "bottom-center" (the vertical place,
// a dash, the horizontal one).
Rectangle {
  id: root

  property string position: "top-right"

  readonly property var parts: root.position.split("-")
  readonly property string vertical: root.parts[0] ?? "top"
  readonly property string horizontal: root.parts[1] ?? "right"
  readonly property int margin: Math.round(root.height * 0.14)

  implicitWidth: 44
  implicitHeight: 28
  radius: Theme.radiusFor(6)
  color: "transparent"
  border.color: Theme.textColor
  border.width: 2
  opacity: 0.9

  Rectangle {
    width: root.width * 0.36
    height: root.height * 0.29
    radius: Theme.radiusFor(3)
    color: Theme.accentColor
    x: root.horizontal === "left" ? root.margin + 2
      : root.horizontal === "right" ? root.width - width - root.margin - 2
      : (root.width - width) / 2
    y: root.vertical === "top" ? root.margin + 2
      : root.vertical === "bottom" ? root.height - height - root.margin - 2
      : (root.height - height) / 2
  }
}
