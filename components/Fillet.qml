import QtQuick
import QtQuick.Shapes
import qs.config

// One concave corner (fillet) where two surfaces meet at a right angle: a
// square of `size`, less the quarter circle centered on the corner opposite
// the two edges it hugs. By default it hugs its top and right edges (the
// fillet left of a panel under a top bar: the bar above, the panel to the
// right); `mirrorX` makes it hug its left edge instead, `mirrorY` its bottom.
Shape {
  id: root

  property real size
  property color color
  property color borderColor
  property bool mirrorX: false
  property bool mirrorY: false

  width: root.size
  height: root.size
  preferredRendererType: Shape.CurveRenderer

  transform: Scale {
    origin.x: root.size / 2
    origin.y: root.size / 2
    xScale: root.mirrorX ? -1 : 1
    yScale: root.mirrorY ? -1 : 1
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
