import QtQuick
import qs.components
import qs.config
import qs.services

// Icon that locks the screen.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.height

  BarText {
    id: icon
    anchors.centerIn: parent
    text: "󰌾"
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Lock.lock()
  }
}
