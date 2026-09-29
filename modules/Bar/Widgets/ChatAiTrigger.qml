import QtQuick
import qs.components
import qs.config

// Icon that opens or closes the chat AI panel.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.height

  BarText {
    id: icon
    anchors.centerIn: parent
    text: "󰭹"
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: ChatAiState.toggle()
  }
}
