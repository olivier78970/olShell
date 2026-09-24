import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Output volume percentage; scroll over it to adjust, click to open or close
// pavucontrol.
Item {
  id: root

  // Fraction of full volume to change per standard wheel notch (120 units
  // of angleDelta). Scaled by actual delta so touchpads/high-res mice,
  // which send many small events per gesture, change volume smoothly
  // instead of snapping by this whole step on every event.
  readonly property real step: 0.03

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 4

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: Audio.icon
      sizeScale: 1.4
    }

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: Audio.percent + "%"
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    // Closes pavucontrol if it's running, opens it otherwise.
    onClicked: Quickshell.execDetached(["sh", "-c", "pkill -x pavucontrol || exec pavucontrol"])
    onWheel: wheel => Audio.adjust((wheel.angleDelta.y / 120) * root.step)
  }
}
