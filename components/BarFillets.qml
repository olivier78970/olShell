import QtQuick
import qs.config

// Concave corners (fillets) on either side of a surface flush against the bar
// - an attached panel, a widget's menu or tooltip - curving from the bar's
// edge into the surface's side, so it seems to grow out of the bar rather
// than hang from it: left and right of it under a top bar, above and below
// it beside a side bar. Only when turned on (Theme.curvedJoins, which needs
// no border), with no gap
// between them (they don't touch otherwise) and in the "full" bar style (the
// "widgets" one has no continuous bar edge above them to curve from).
//
// Fills its parent, the surface, and draws just past its sides, level with
// the bar's edge: under the bar and beside the surface, so it overlaps
// neither (which would draw that spot twice over, darker). Decorative only:
// it takes no input.
Item {
  id: root

  // The surface's own fill and border colors.
  property color color
  property color borderColor
  // How far each fillet reaches along the bar and down the surface's side
  // (across its top or bottom, beside a side bar).
  property real size: Theme.joinRadiusFor(Theme.barVertical ? root.width : root.height)
  // Either side can be left out (e.g. one flush with an end of the bar): the
  // one toward the bar's start (its left end, or its top one on a side bar),
  // or toward its end.
  property bool showStart: true
  property bool showEnd: true

  readonly property bool barAtTop: Theme.barPosition !== "bottom"
  readonly property bool barAtLeft: Theme.barPosition === "left"
  readonly property bool active: Theme.curvedJoins && Theme.panelGap <= 0 && Theme.barStyle === "full" && root.size > 0

  anchors.fill: parent

  // The fillets hug the bar's edge and the surface's side: drawn level with
  // that edge (the surface overlaps the bar's border by the border width, so
  // it's that far into it), on either side of the surface.
  readonly property real filletY: root.barAtTop ? Theme.borderWidth : root.height - Theme.borderWidth - root.size
  readonly property real filletX: root.barAtLeft ? Theme.borderWidth : root.width - Theme.borderWidth - root.size

  // Left of the surface (above it, beside a side bar).
  Fillet {
    visible: root.active && root.showStart
    x: Theme.barVertical ? root.filletX : -root.size
    y: Theme.barVertical ? -root.size : root.filletY
    size: root.size
    color: root.color
    borderColor: root.borderColor
    mirrorX: Theme.barVertical && root.barAtLeft
    mirrorY: Theme.barVertical || !root.barAtTop
  }

  // Right of the surface (below it, beside a side bar).
  Fillet {
    visible: root.active && root.showEnd
    x: Theme.barVertical ? root.filletX : root.width
    y: Theme.barVertical ? root.height : root.filletY
    size: root.size
    color: root.color
    borderColor: root.borderColor
    mirrorX: Theme.barVertical ? root.barAtLeft : true
    mirrorY: !Theme.barVertical && !root.barAtTop
  }
}
