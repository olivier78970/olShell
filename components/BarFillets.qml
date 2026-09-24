import QtQuick
import QtQuick.Shapes
import qs.config

// Concave corners (fillets) on either side of a surface flush against the bar
// - an attached panel, a widget's menu or tooltip - curving from the bar's
// edge into the surface's side, so it seems to grow out of the bar rather
// than hang from it. Only when turned on (Settings.panelCurves), with no gap
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
  readonly property bool active: Theme.panelCurves && Theme.panelGap <= 0 && Theme.barStyle === "full" && root.size > 0

  anchors.fill: parent

  // One fillet, drawn as the one left of a surface under a top bar: the
  // square it fits in, less the quarter circle centered on its bottom-left
  // corner. Mirrored for the other side and for a bottom bar.
  component Fillet: Shape {
    id: fillet

    property bool mirrorX: false

    width: root.size
    height: root.size
    // The surface overlaps the bar's border by the border width, so the
    // bar's edge is that far into it.
    y: root.barAtTop ? Theme.borderWidth : root.height - Theme.borderWidth - root.size
    preferredRendererType: Shape.CurveRenderer

    transform: Scale {
      origin.x: root.size / 2
      origin.y: root.size / 2
      xScale: fillet.mirrorX ? -1 : 1
      yScale: root.barAtTop ? 1 : -1
    }

    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"
      startX: 0
      startY: 0

      PathLine { x: root.size; y: 0 }
      PathLine { x: root.size; y: root.size }
      PathArc {
        x: 0
        y: 0
        radiusX: root.size
        radiusY: root.size
        direction: PathArc.Counterclockwise
      }
    }

    // The border carries on along the curve.
    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.borderWidth > 0 ? root.borderColor : "transparent"
      strokeWidth: Theme.borderWidth
      startX: root.size
      startY: root.size

      PathArc {
        x: 0
        y: 0
        radiusX: root.size
        radiusY: root.size
        direction: PathArc.Counterclockwise
      }
    }
  }

  Fillet {
    visible: root.active && root.showLeft
    x: -root.size
  }

  Fillet {
    visible: root.active && root.showRight
    x: root.width
    mirrorX: true
  }
}
