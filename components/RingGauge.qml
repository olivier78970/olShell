import QtQuick
import QtQuick.Shapes
import qs.config

// A circular gauge: a 270 degree track with the value swept along it, and
// the value's text in the middle. `value` runs from 0 to 1 and animates.
// Turns to the warning color above `warnAbove`.
Item {
  id: root

  property real value: 0
  property real warnAbove: 0.9
  property string text: ""
  property string caption: ""
  property real thickness: 8

  readonly property color barColor: root.value > root.warnAbove ? Theme.warningColor : Theme.accentColor
  // The value drawn, which eases toward `value`.
  property real shown: 0

  implicitWidth: 96
  implicitHeight: 96

  onValueChanged: root.shown = Math.max(0, Math.min(1, root.value))
  Component.onCompleted: root.shown = Math.max(0, Math.min(1, root.value))

  Behavior on shown {
    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // Track
    ShapePath {
      strokeColor: Theme.borderColor
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: (Math.min(root.width, root.height) - root.thickness) / 2
        radiusY: radiusX
        startAngle: 135
        sweepAngle: 270
      }
    }

    // Value
    ShapePath {
      strokeColor: root.barColor
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: root.width / 2
        centerY: root.height / 2
        radiusX: (Math.min(root.width, root.height) - root.thickness) / 2
        radiusY: radiusX
        startAngle: 135
        sweepAngle: Math.max(0.01, 270 * root.shown)
      }
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 0

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.text
      sizeScale: 1.3
    }

    ThemedText {
      visible: text.length > 0
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.caption
      opacity: 0.6
      sizeScale: 0.6
    }
  }
}
