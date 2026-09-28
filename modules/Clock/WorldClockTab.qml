import QtQuick
import qs.components
import qs.config
import qs.modules.Settings
import qs.services

// The clocks page of the clock popup: the time here, large, by an analog
// clock and today's date, then a card for each place set in the settings
// (Settings.worldClocks, see services/WorldClock.qml), two to a row: an
// analog clock, the place, its time, and as pills the day it is there next
// to today's and how far ahead or behind it is. A place's card is tinted
// warm by day and deep blue by night. With no place yet, a button opens the
// settings where they're added.
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

  // How far a zone is ahead of (or behind) here, and its zone's abbreviation
  // when it has a real one (some zones only have "+07").
  function zoneText(zone) {
    const abbrev = WorldClock.zones[zone]?.abbrev ?? ""
    return [root.offsetText(zone), /^[+-]/.test(abbrev) ? "" : abbrev].filter(part => part.length > 0).join("  ")
  }

  // The tints of a place's card by day and by night.
  readonly property color dayTint: "#f6b73c"
  readonly property color nightTint: "#3b4a9c"

  // Whether it's night at `date` (before 6 or from 20 o'clock).
  function isNight(date) {
    return date.getHours() < 6 || date.getHours() >= 20
  }

  // A clock hand on a face `size` wide: `length` (of the radius) long,
  // `thickness` wide, turned `angle` degrees from 12 o'clock.
  component Hand: Rectangle {
    id: hand

    property real size: 64
    property real length: 0.5
    property real thickness: 2
    property real angle: 0

    x: (hand.size - width) / 2
    y: hand.size / 2 - height + hand.thickness / 2
    width: hand.thickness
    height: hand.size / 2 * hand.length
    radius: hand.thickness / 2
    antialiasing: true
    transform: Rotation {
      origin.x: hand.width / 2
      origin.y: hand.height - hand.thickness / 2
      angle: hand.angle
    }
  }

  // An analog clock showing `time`: a face with its twelve marks, and the
  // hour, minute and (with `seconds`) second hands. Lighter by day, darker by
  // night.
  component ClockFace: Item {
    id: face

    property var time: null
    property bool seconds: false
    readonly property bool night: face.time ? root.isNight(face.time) : false
    readonly property real hours: face.time ? face.time.getHours() % 12 + face.time.getMinutes() / 60 : 0
    readonly property real minutes: face.time ? face.time.getMinutes() + face.time.getSeconds() / 60 : 0

    implicitWidth: 64
    implicitHeight: 64

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: face.night ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.12)
      border.color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.35)
      border.width: 1
    }

    // The marks, longer at 12, 3, 6 and 9.
    Repeater {
      model: 12

      Rectangle {
        required property int index
        readonly property bool major: index % 3 === 0

        x: (face.width - width) / 2
        y: face.height * 0.06
        width: major ? 2 : 1
        height: face.height * (major ? 0.1 : 0.06)
        color: Theme.textColor
        opacity: major ? 0.8 : 0.4
        transform: Rotation {
          origin.x: width / 2
          origin.y: face.height / 2 - face.height * 0.06
          angle: index * 30
        }
      }
    }

    Hand {
      size: face.width
      length: 0.55
      thickness: face.width / 22
      angle: face.hours * 30
      color: Theme.textColor
    }

    Hand {
      size: face.width
      length: 0.8
      thickness: face.width / 32
      angle: face.minutes * 6
      color: Theme.textColor
    }

    Hand {
      size: face.width
      visible: face.seconds
      length: 0.85
      thickness: 1
      angle: face.time ? face.time.getSeconds() * 6 : 0
      color: Theme.accentColor
    }

    Rectangle {
      anchors.centerIn: parent
      width: face.width / 12
      height: width
      radius: width / 2
      color: Theme.accentColor
    }
  }

  // A small rounded label.
  component Pill: Rectangle {
    property alias text: pillText.text

    width: pillText.implicitWidth + 12
    height: pillText.implicitHeight + 4
    radius: height / 2
    color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.1)

    ThemedText {
      id: pillText
      anchors.centerIn: parent
      sizeScale: 0.65
      opacity: 0.85
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
    spacing: 10

    // Here: a larger clock, the time and today's date, centered.
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 18

      ClockFace {
        width: 92
        height: 92
        time: root.now
        seconds: true
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        ThemedText {
          text: I18n.tr("clock.world.here")
          sizeScale: 0.75
          color: Theme.accentColor
          font.bold: true
        }

        ThemedText {
          text: root.timeText(root.now)
          sizeScale: 2.4
          font.bold: true
        }

        ThemedText {
          text: {
            const date = root.now.toLocaleDateString(I18n.locale, I18n.value("format.date.long"))
            return date.charAt(0).toUpperCase() + date.slice(1)
          }
          sizeScale: 0.75
          opacity: 0.65
        }
      }
    }

    // The places, two to a row (or one, alone).
    Grid {
      id: grid
      width: parent.width
      columns: Settings.worldClocks.length > 1 ? 2 : 1
      spacing: 8

      Repeater {
        model: Settings.worldClocks

        Rectangle {
          id: card

          required property var modelData
          readonly property var time: WorldClock.timeIn(card.modelData.zone, root.now)
          readonly property bool night: card.time ? root.isNight(card.time) : false
          readonly property color tint: card.night ? root.nightTint : root.dayTint

          width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
          height: Math.max(face.height, details.implicitHeight) + 20
          radius: Theme.radiusFor(Math.min(height, 60))
          // The panel's own card color, tinted by day or night.
          color: Qt.tint(Qt.rgba(Theme.backgroundColor.r, Theme.backgroundColor.g, Theme.backgroundColor.b, 0.5), Qt.rgba(card.tint.r, card.tint.g, card.tint.b, card.night ? 0.3 : 0.16))
          border.color: Qt.rgba(card.tint.r, card.tint.g, card.tint.b, 0.45)
          border.width: 1

          ClockFace {
            id: face
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 58
            height: 58
            time: card.time
          }

          Column {
            id: details
            anchors.left: face.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            ThemedText {
              width: parent.width
              elide: Text.ElideRight
              text: card.modelData.name.split(",")[0]
              font.bold: true
              sizeScale: 0.85
            }

            Row {
              spacing: 6

              ThemedText {
                anchors.verticalCenter: parent.verticalCenter
                text: card.time ? root.timeText(card.time) : "–:––"
                sizeScale: 1.5
                font.bold: true
              }

              ThemedText {
                anchors.verticalCenter: parent.verticalCenter
                text: card.night ? "󰖔" : "󰖙"
                color: card.tint
                sizeScale: 0.9
              }
            }

            Flow {
              width: parent.width
              spacing: 4

              Pill {
                visible: card.time !== null
                text: card.time ? root.dayText(card.time) : ""
              }

              Pill {
                visible: text.length > 0
                text: root.zoneText(card.modelData.zone)
              }
            }
          }
        }
      }
    }
  }
}
