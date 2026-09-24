import QtQuick
import qs.components
import qs.config

// Icon that opens the wallpaper panel, attached below it on the bar.
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
    onClicked: WallpaperPanelState.toggle(root)
  }
}
