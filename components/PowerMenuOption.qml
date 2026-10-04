import QtQuick
import qs.config

// A single clickable row inside a menu, in the accent color while `active`
// (the current choice of a menu that picks one).
Rectangle {
  id: root

  property string label: ""
  property string icon: ""
  // An image shown in place of `icon` when set (a web app's favicon).
  property string iconSource: ""
  property bool active: false
  // A dot after the label (a web app whose window is open).
  property bool marked: false
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

    Image {
      visible: root.iconSource.length > 0
      anchors.verticalCenter: parent.verticalCenter
      width: Theme.fontSize()
      height: width
      sourceSize.width: width * 2
      sourceSize.height: height * 2
      source: root.iconSource
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
    }

    ThemedText {
      visible: root.icon.length > 0 && root.iconSource.length === 0
      text: root.icon
      color: mouseArea.containsMouse ? Theme.backgroundColor : (root.active ? Theme.accentColor : Theme.textColor)
    }

    ThemedText {
      text: root.label
      color: mouseArea.containsMouse ? Theme.backgroundColor : (root.active ? Theme.accentColor : Theme.textColor)
    }

    Rectangle {
      visible: root.marked
      anchors.verticalCenter: parent.verticalCenter
      width: 6
      height: 6
      radius: 3
      color: mouseArea.containsMouse ? Theme.backgroundColor : Theme.accentColor
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
