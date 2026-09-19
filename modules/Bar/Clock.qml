import QtQuick
import qs.config

// Centered date/time display (French locale). Hovering it opens the popup
// with the agenda and the performance figures.
Item {
  id: root

  readonly property var locale: Qt.locale("fr_FR")
  property date now: new Date()

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 4

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
    }

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: root.now.toLocaleString(root.locale, "dddd d MMMM yyyy HH:mm:ss")
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  HoverPopup {
    id: popup
    anchorItem: root
    alignCenter: true
    keepOpen: true

    ClockPanel {}
  }
}
