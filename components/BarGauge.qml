import QtQuick
import QtQuick.Shapes
import qs.config

// A small ring filled clockwise from the top in proportion to `value` (0 to
// 1), over a faint full ring, with `icon` in its middle: how a bar widget
// shows a percentage on a side bar, where there's no room for the figure
// itself (its popup gives it instead). The clock panel's larger gauge, with
// the figure inside, is RingGauge.
Item {
  id: root

  property real value: 0
  property string icon: ""
  property color color: Theme.accentColor
  // The icon's color (the ring's own, for a warning, say).
  property color iconColor: Theme.textColor
  // How thick the ring is, in pixels.
  property real thickness: 3
  // The value as drawn, eased toward `value` so the ring doesn't jump.
  property real shown: Math.max(0, Math.min(1, root.value))

  Behavior on shown {
    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
  }

  // Most of the bar's thickness, leaving room either side.
  implicitWidth: Math.round(Theme.barHeight * 0.7)
  implicitHeight: implicitWidth

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // The whole ring, faint.
    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.fade(Theme.textColor, 0.15)
      strokeWidth: root.thickness
      capStyle: ShapePath.FlatCap

      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: (root.width - root.thickness) / 2
        radiusY: (root.height - root.thickness) / 2
        startAngle: 0
        sweepAngle: 360
      }
    }

    // The filled part, from the top.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.shown > 0 ? root.color : "transparent"
      strokeWidth: root.thickness
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: (root.width - root.thickness) / 2
        radiusY: (root.height - root.thickness) / 2
        startAngle: -90
        sweepAngle: 360 * root.shown
      }
    }
  }

  ThemedText {
    anchors.centerIn: parent
    text: root.icon
    color: root.iconColor
    sizeScale: 0.8
  }
}
