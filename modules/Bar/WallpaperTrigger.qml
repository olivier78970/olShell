import QtQuick
import qs.config

// Icon that opens the screen-centered wallpaper panel.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  ThemedText {
    id: icon
    anchors.centerIn: parent
    text: "󰋩"
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: WallpaperPanelState.toggle()
  }
}
