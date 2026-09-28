import QtQuick
import qs.components
import qs.config
import qs.modules.Settings
import qs.services

// The clocks page of the clock popup: the time here, then the time now in
// each place set in the settings (Settings.worldClocks, see
// services/WorldClock.qml), each with whether it's day or night there, the
// day it is there next to today's, and how far ahead or behind it is. With
// no place yet, a button opens the settings where they're added.
Item {
  id: root

  implicitHeight: Settings.worldClocks.length > 0 ? column.implicitHeight : empty.implicitHeight

  // The time now, moved on every second while the page shows.
  property date now: new Date()

  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // The time of a Date, as the language writes it.
  function timeText(date) {
    return date.toLocaleTimeString(I18n.locale, Locale.ShortFormat)
  }

  // How far a zone is ahead of (or behind) here: "+7 h", "−5 h 30", or "same time".
  function offsetText(zone) {
    const known = WorldClock.zones[zone]
    if (!known) return ""
    const minutes = Math.round((known.offset - WorldClock.localOffset()) / 60)
    if (minutes === 0) return I18n.tr("clock.world.same")
    const hours = Math.floor(Math.abs(minutes) / 60)
    const rest = Math.abs(minutes) % 60
    return (minutes > 0 ? "+" : "−") + hours + " h" + (rest > 0 ? " " + String(rest).padStart(2, "0") : "")
  }

  // The day it is at `date` (a place's wall clock), next to today here.
  function dayText(date) {
    const here = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate())
    const there = new Date(date.getFullYear(), date.getMonth(), date.getDate())
    const days = Math.round((there - here) / 86400000)
    return days > 0 ? I18n.tr("clock.world.tomorrow") : days < 0 ? I18n.tr("clock.world.yesterday") : I18n.tr("clock.world.today")
  }

  // Whether it's night at `date` (before 6 or from 20 o'clock).
  function isNight(date) {
    return date.getHours() < 6 || date.getHours() >= 20
  }

  // A place's row: its name and details on the left, its time on the right.
  component PlaceRow: Item {
    id: place

    property string name: ""
    property string details: ""
    property var time: null
    property bool here: false

    width: parent.width
    height: Math.max(names.implicitHeight, clock.implicitHeight) + 12

    Column {
      id: names
      anchors.left: parent.left
      anchors.right: clock.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

      ThemedText {
        width: parent.width
        elide: Text.ElideRight
        text: place.name
        font.bold: true
        color: place.here ? Theme.accentColor : Theme.textColor
      }

      ThemedText {
        visible: text.length > 0
        width: parent.width
        elide: Text.ElideRight
        text: place.details
        sizeScale: 0.7
        opacity: 0.65
      }
    }

    Row {
      id: clock
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: place.time ? (root.isNight(place.time) ? "󰖔" : "󰖙") : ""
        color: Theme.accentColor
        opacity: 0.8
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: place.time ? root.timeText(place.time) : "–:––"
        sizeScale: 1.6
        font.bold: true
      }
    }
  }

  // No place yet.
  Column {
    id: empty
    visible: Settings.worldClocks.length === 0
    width: parent.width
    topPadding: 30
    bottomPadding: 30
    spacing: 10

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "󰥔"
      sizeScale: 2.4
      opacity: 0.5
    }

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(implicitWidth, parent.width)
      wrapMode: Text.Wrap
      horizontalAlignment: Text.AlignHCenter
      text: I18n.tr("clock.world.none")
      opacity: 0.6
    }

    // Opens the settings on the Panels category's Clock tab.
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: openText.implicitWidth + 24
      height: openText.implicitHeight + 10
      radius: Theme.radiusFor(height)
      color: openMouse.containsMouse ? Theme.borderColor : "transparent"
      border.color: Theme.outlineColor
      border.width: 1

      ThemedText {
        id: openText
        anchors.centerIn: parent
        text: I18n.tr("clock.world.openSettings")
        sizeScale: 0.8
      }

      MouseArea {
        id: openMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          const category = SettingsPages.categories.findIndex(category => (category.tabs ?? []).some(tab => tab.id === "clockPanel"))
          SettingsPanelState.category = category
          SettingsPanelState.tab = SettingsPages.categories[category].tabs.findIndex(tab => tab.id === "clockPanel")
          SettingsPanelState.toggle()
        }
      }
    }
  }

  Column {
    id: column
    visible: Settings.worldClocks.length > 0
    width: parent.width
    spacing: 0

    PlaceRow {
      name: I18n.tr("clock.world.here")
      details: root.dayText(root.now)
      time: root.now
      here: true
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.outlineColor
      opacity: 0.5
    }

    Repeater {
      model: Settings.worldClocks

      PlaceRow {
        required property var modelData

        readonly property var zoneTime: WorldClock.timeIn(modelData.zone, root.now)

        name: modelData.name
        // Its day, how far ahead or behind, and its zone's abbreviation
        // when it has a real one (some zones only have "+07").
        readonly property string abbrev: WorldClock.zones[modelData.zone]?.abbrev ?? ""
        details: zoneTime ? [root.dayText(zoneTime), root.offsetText(modelData.zone), /^[+-]/.test(abbrev) ? "" : abbrev]
          .filter(part => part.length > 0).join("  ·  ") : ""
        time: zoneTime
      }
    }
  }
}
