import QtQuick
import qs.components
import qs.config

// Centered date/time display, in the current language, with the date format
// and seconds chosen in the settings (Settings.clockDate, clockSeconds). On a
// side bar the time is stacked instead, hours over minutes (over seconds),
// with the short day name and the day of the month under it (any date
// format but "none").
// Clicking it opens (or
// closes) the clock panel (modules/Clock/ClockPanel.qml) with the agenda and
// the performance figures; a click elsewhere closes it too.
Item {
  id: root

  readonly property var locale: I18n.locale
  property date now: new Date()
  // What is shown: the date in the chosen format (none for "none"), then the
  // time, with or without seconds.
  readonly property string format: (Settings.clockDate === "none" ? "" : I18n.value("format.date." + Settings.clockDate) + " ")
    + I18n.value(Settings.clockSeconds ? "format.timeSeconds" : "format.time")
  // Whether this instance's clock is the one with the panel open right now
  // (the bar keeps the widget's section open then) - the panel is a single
  // top-level instance shared by every screen's bar, so only the clock that
  // opened it counts.
  readonly property bool menuOpen: ClockPanelState.visible && ClockPanelState.anchorItem === root

  // What is shown on a side bar, one line each: the time's parts, then the
  // date's.
  readonly property var stackedLines: {
    const time = root.now.toLocaleString(root.locale, I18n.value(Settings.clockSeconds ? "format.timeSeconds" : "format.time")).split(":")
    const date = Settings.clockDate === "none" ? [] : [root.now.toLocaleString(root.locale, "ddd"), root.now.toLocaleString(root.locale, "d")]
    return { time: time, date: date }
  }

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: Theme.barVertical ? stacked.implicitWidth : content.implicitWidth
  implicitHeight: Theme.barVertical ? stacked.implicitHeight : content.implicitHeight

  Row {
    id: content
    visible: !Theme.barVertical
    anchors.centerIn: parent
    spacing: 4

    BarText {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
    }

    BarText {
      anchors.verticalCenter: parent.verticalCenter
      text: root.now.toLocaleString(root.locale, root.format)
    }
  }

  Column {
    id: stacked
    visible: Theme.barVertical
    anchors.centerIn: parent
    spacing: 0

    Repeater {
      model: root.stackedLines.time

      BarText {
        required property string modelData

        anchors.horizontalCenter: parent.horizontalCenter
        text: modelData
      }
    }

    // A little room between the time and the date.
    Item {
      visible: root.stackedLines.date.length > 0
      width: 1
      height: 4
    }

    Repeater {
      model: root.stackedLines.date

      BarText {
        required property string modelData

        anchors.horizontalCenter: parent.horizontalCenter
        text: modelData
        sizeScale: Theme.barFigureScale
        opacity: 0.7
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: ClockPanelState.toggle(root)
  }

  // Updates the time just after the next second, or the next minute without
  // seconds, so the bar isn't redrawn more often than the clock changes.
  function tick() {
    root.now = new Date()
    const period = Settings.clockSeconds ? 1000 : 60000
    ticker.interval = period - (root.now.getTime() % period) + 20
    ticker.restart()
  }

  Component.onCompleted: root.tick()

  Connections {
    target: Settings

    function onClockSecondsChanged() {
      root.tick()
    }
  }

  Timer {
    id: ticker
    onTriggered: root.tick()
  }
}
