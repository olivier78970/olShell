import QtQuick
import qs.components
import qs.config

// Centered date/time display, in the current language. Clicking it opens (or
// closes) the clock panel (modules/Clock/ClockPanel.qml) with the agenda and
// the performance figures; a click elsewhere closes it too.
Item {
  id: root

  readonly property var locale: I18n.locale
  property date now: new Date()
  // Whether this instance's clock is the one with the panel open right now
  // (the bar keeps the widget's section open then) - the panel is a single
  // top-level instance shared by every screen's bar, so only the clock that
  // opened it counts.
  readonly property bool menuOpen: ClockPanelState.visible && ClockPanelState.anchorItem === root

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
    onClicked: ClockPanelState.toggle(root)
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }
}
