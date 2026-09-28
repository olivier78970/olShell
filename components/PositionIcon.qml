import QtQuick
import qs.config

// A small screen with a block where something is placed on it, for a position
// such as "top-right", "center-left" or "bottom-center" (the vertical place,
// a dash, the horizontal one). A position with no dash ("top", "bottom",
// "left" or "right") is an edge to hug in full, drawn as a bar spanning that
// edge. A panel's placement (Settings.panelPlacements) is drawn the same way:
// "center" in the middle of the screen, "center-left" and "center-right" as
// they read, "bar-left", "bar-center" or "bar-right" on the bar's edge
// (Theme.barPosition; from its top to its bottom on a side bar), and
// "opposite-..." on the other one; "each" (each panel its own place) is the
// screen with no block.
Rectangle {
  id: root

  property string position: "top-right"

  // The position as a place on the screen, a panel's placement included.
  readonly property string place: root.position === "center" ? "center-center"
    : root.position.startsWith("bar-") ? root.onEdge(Theme.barPosition, root.position.slice(4))
    : root.position.startsWith("opposite-") ? root.onEdge(({ top: "bottom", bottom: "top", left: "right", right: "left" })[Theme.barPosition], root.position.slice(9))
    : root.position
  readonly property var parts: root.place.split("-")
  readonly property bool edgeOnly: root.parts.length === 1
  // Whether it hugs the left or right edge in full.
  readonly property bool sideEdge: root.edgeOnly && (root.parts[0] === "left" || root.parts[0] === "right")
  readonly property string vertical: root.sideEdge ? "center" : root.parts[0] ?? "top"
  readonly property string horizontal: root.sideEdge ? root.parts[0] : root.parts[1] ?? "right"

  // The place at `along` ("left", "center" or "right"; from top to bottom on
  // a side) on the screen's `edge`.
  function onEdge(edge, along) {
    if (edge === "top" || edge === "bottom") return edge + "-" + along
    return ({ left: "top", center: "center", right: "bottom" })[along] + "-" + edge
  }
  readonly property int margin: Math.round(root.height * 0.14)

  implicitWidth: 44
  implicitHeight: 28
  radius: Theme.radiusFor(6)
  color: "transparent"
  border.color: Theme.textColor
  border.width: 2
  opacity: 0.9

  Rectangle {
    visible: root.position !== "each"
    width: root.sideEdge ? root.width * 0.2 : root.edgeOnly ? root.width - root.margin * 2 - 4 : root.width * 0.36
    height: root.sideEdge ? root.height - root.margin * 2 - 4 : root.height * 0.29
    radius: Theme.radiusFor(3)
    color: Theme.accentColor
    x: root.edgeOnly && !root.sideEdge ? root.margin + 2
      : root.horizontal === "left" ? root.margin + 2
      : root.horizontal === "right" ? root.width - width - root.margin - 2
      : (root.width - width) / 2
    y: root.vertical === "top" ? root.margin + 2
      : root.vertical === "bottom" ? root.height - height - root.margin - 2
      : (root.height - height) / 2
  }
}
