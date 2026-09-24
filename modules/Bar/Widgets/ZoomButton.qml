import QtQuick
import qs.components
import qs.config
import qs.services

// Magnifier icon for the screen zoom (services/Zoom.qml): the wheel over it
// zooms in and out, and a click zooms back out.
// While zoomed, the factor shows next to the icon.
Item {
  id: root

  // Wheel movement not yet turned into a zoom step: a mouse wheel sends 120
  // per notch, a touchpad or smooth-scrolling wheel many small amounts, and
  // each notch's worth is one Settings.zoomStep.
  property real wheelAccumulated: 0

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: "󱡴"
    }

    ThemedText {
      visible: Zoom.zoomed
      anchors.verticalCenter: parent.verticalCenter
      text: "×" + Zoom.factor.toFixed(1)
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Zoom.reset()
    onExited: root.wheelAccumulated = 0
    onWheel: wheel => {
      root.wheelAccumulated += wheel.angleDelta.y
      while (Math.abs(root.wheelAccumulated) >= 120) {
        const up = root.wheelAccumulated > 0
        if (up) Zoom.zoomIn()
        else Zoom.zoomOut()
        root.wheelAccumulated -= up ? 120 : -120
      }
    }
  }
}
