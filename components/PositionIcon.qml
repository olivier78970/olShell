import QtQuick
import qs.config

// A small screen with a block where something is placed on it, for a position
// such as "top-right", "center-left" or "bottom-center" (the vertical place,
// a dash, the horizontal one). A position with no dash (just "top" or
// "bottom") is an edge to hug in full, drawn as a bar spanning that edge. A
// panel's placement (Settings.panelPlacements) is drawn the same way: "center"
// in the middle of the screen, "bar-left", "bar-center" or "bar-right" on the
// bar's edge (Theme.barPosition), and "opposite-..." on the other one.
Rectangle {
  id: root

  property string position: "top-right"

  // The position as a place on the screen, a panel's placement included.
  readonly property string place: root.position === "center" ? "center-center"
    : root.position.startsWith("bar-") ? (Theme.barPosition === "bottom" ? "bottom" : "top") + root.position.slice(3)
    : root.position.startsWith("opposite-") ? (Theme.barPosition === "bottom" ? "top" : "bottom") + root.position.slice(8)
    : root.position
  readonly property var parts: root.place.split("-")
  readonly property bool edgeOnly: root.parts.length === 1
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
    width: root.edgeOnly ? root.width - root.margin * 2 - 4 : root.width * 0.36
    height: root.height * 0.29
    radius: Theme.radiusFor(3)
    color: Theme.accentColor
    x: root.edgeOnly ? root.margin + 2
      : root.horizontal === "left" ? root.margin + 2
      : root.horizontal === "right" ? root.width - width - root.margin - 2
      : (root.width - width) / 2
    y: root.vertical === "top" ? root.margin + 2
      : root.vertical === "bottom" ? root.height - height - root.margin - 2
      : (root.height - height) / 2
  }
}
