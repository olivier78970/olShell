import QtQuick
import Quickshell.Io
import qs.config
import qs.services

// Output volume percentage; scroll over it to adjust.
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
    onClicked: pavucontrolProcess.running = true
    onWheel: wheel => Audio.adjust((wheel.angleDelta.y / 120) * root.step)
  }

  Process {
    id: pavucontrolProcess
    command: Apps.volumeMixer
  }
}
