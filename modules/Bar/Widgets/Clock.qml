import QtQuick
import qs.components
import qs.config

// Centered date/time display, in the current language. Clicking it opens (or
// closes) the popup with the agenda and the performance figures; a click
// elsewhere closes it too.
Item {
  id: root

  readonly property var locale: I18n.locale
  property date now: new Date()
  // Whether the popup is open (the bar keeps the widget's section open then).
  readonly property bool menuOpen: popup.visible

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
      text: root.now.toLocaleString(root.locale, I18n.value("format.dateTime"))
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.visible = !popup.visible
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  BlurPopupMenu {
    id: popup
    anchorItem: root
    alignCenter: true

    ClockPanel {}
  }
}
