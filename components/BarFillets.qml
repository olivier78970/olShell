import QtQuick
import qs.config

// Concave corners (fillets) on either side of a surface flush against the bar
// - an attached panel, a widget's menu or tooltip - curving from the bar's
// edge into the surface's side, so it seems to grow out of the bar rather
// than hang from it. Only when turned on (Settings.curvedJoins), with no gap
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
  // How far each fillet reaches along the bar and down the surface's side.
  property real size: Theme.radiusFor(root.height)
  // Either side can be left out (e.g. one flush with an end of the bar).
  property bool showLeft: true
  property bool showRight: true

  readonly property bool barAtTop: Theme.barPosition !== "bottom"
  readonly property bool active: Theme.curvedJoins && Theme.panelGap <= 0 && Theme.barStyle === "full" && root.size > 0

  anchors.fill: parent

  // The fillets hug the bar's edge and the surface's side: drawn level with
  // that edge (the surface overlaps the bar's border by the border width, so
  // it's that far into it), on either side of the surface.
  readonly property real filletY: root.barAtTop ? Theme.borderWidth : root.height - Theme.borderWidth - root.size

  Fillet {
    visible: root.active && root.showLeft
    x: -root.size
    y: root.filletY
    size: root.size
    color: root.color
    borderColor: root.borderColor
    mirrorY: !root.barAtTop
  }

  Fillet {
    visible: root.active && root.showRight
    x: root.width
    y: root.filletY
    size: root.size
    color: root.color
    borderColor: root.borderColor
    mirrorX: true
    mirrorY: !root.barAtTop
  }
}
