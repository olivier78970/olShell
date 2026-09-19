import QtQuick
import qs.config

// A single clickable row inside the power menu.
Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  signal clicked()

  implicitWidth: content.implicitWidth + 24
  implicitHeight: Theme.fontSize() + 16
  width: implicitWidth
  height: implicitHeight
  radius: Theme.radiusFor(height)
  opacity: enabled ? 1 : 0.4
  color: mouseArea.containsMouse ? Theme.accentColor : "transparent"

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 8

    ThemedText {
      visible: root.icon.length > 0
      text: root.icon
      color: mouseArea.containsMouse ? Theme.backgroundColor : Theme.textColor
    }

    ThemedText {
      text: root.label
      color: mouseArea.containsMouse ? Theme.backgroundColor : Theme.textColor
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
