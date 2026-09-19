import QtQuick
import Quickshell
import qs.components
import qs.config

// The agenda page of the clock popup: a month calendar (weeks start on
// Monday, ISO week numbers) with the current day highlighted. The arrows
// browse months; "Aujourd'hui" jumps back to the current one.
Item {
  id: root

  readonly property var locale: I18n.locale
  readonly property date today: clock.date
  // The month being shown (any day in it; only year and month are used).
  property int viewYear: root.today.getFullYear()
  property int viewMonth: root.today.getMonth()

  readonly property bool onCurrentMonth: root.viewYear === root.today.getFullYear() && root.viewMonth === root.today.getMonth()
  readonly property string monthTitle: {
    const name = root.locale.monthName(root.viewMonth, Locale.LongFormat)
    return name.charAt(0).toUpperCase() + name.slice(1) + " " + root.viewYear
  }

  // Columns: the week number, then the seven days.
  readonly property real cellWidth: width / 8
  readonly property real cellHeight: 38

  implicitHeight: column.implicitHeight

  function shiftMonth(delta) {
    const target = new Date(root.viewYear, root.viewMonth + delta, 1)
    root.viewYear = target.getFullYear()
    root.viewMonth = target.getMonth()
  }

  function showToday() {
    root.viewYear = root.today.getFullYear()
    root.viewMonth = root.today.getMonth()
  }

  // Date shown in grid cell `cell` (0..41), starting on the Monday on or
  // before the 1st of the shown month.
  function dateOf(cell) {
    const first = new Date(root.viewYear, root.viewMonth, 1)
    const offset = (first.getDay() + 6) % 7
    return new Date(root.viewYear, root.viewMonth, 1 - offset + cell)
  }

  // ISO 8601 week number of a date.
  function isoWeek(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    const day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Column {
    id: column
    width: parent.width
    spacing: 8

    // Month navigation
    Item {
      width: parent.width
      height: Math.max(previous.implicitHeight, todayButton.implicitHeight)

      IconButton {
        id: previous
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰅁"
        onClicked: root.shiftMonth(-1)
      }

      IconButton {
        id: next
        anchors.left: previous.right
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰅂"
        onClicked: root.shiftMonth(1)
      }

      ThemedText {
        anchors.left: next.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.monthTitle
      }

      PowerMenuOption {
        id: todayButton
        visible: !root.onCurrentMonth
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        label: I18n.tr("agenda.today")
        onClicked: root.showToday()
      }
    }

    // Weekday names, Monday first
    Row {
      ThemedText {
        width: root.cellWidth
        height: root.cellHeight * 0.7
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: I18n.tr("agenda.week")
        opacity: 0.5
        sizeScale: 0.65
      }

      Repeater {
        model: 7

        ThemedText {
          required property int index

          width: root.cellWidth
          height: root.cellHeight * 0.7
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          // Locale day numbers run 0 = Sunday, so Monday is 1 and Sunday wraps to 0.
          text: root.locale.dayName((index + 1) % 7, Locale.ShortFormat).replace(".", "")
          opacity: 0.7
          sizeScale: 0.65
        }
      }
    }

    // Six weeks: week number + seven days
    Grid {
      columns: 8
      rowSpacing: 0
      columnSpacing: 0

      Repeater {
        model: 48

        Item {
          id: cell

          required property int index
          readonly property int week: Math.floor(cell.index / 8)
          readonly property int column: cell.index % 8
          readonly property bool isWeekNumber: cell.column === 0
          // The week-number cell uses the row's Monday (the first day column).
          readonly property date date: root.dateOf(cell.week * 7 + Math.max(0, cell.column - 1))
          readonly property bool isToday: !cell.isWeekNumber && root.sameDay(cell.date, root.today)
          readonly property bool inMonth: cell.date.getMonth() === root.viewMonth

          width: root.cellWidth
          height: root.cellHeight

          Rectangle {
            visible: cell.isToday || (!cell.isWeekNumber && dayMouse.containsMouse)
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, 48) - 4
            height: width
            radius: Theme.radiusFor(height)
            color: cell.isToday ? Theme.accentColor : Theme.borderColor
          }

          ThemedText {
            anchors.centerIn: parent
            text: cell.isWeekNumber ? root.isoWeek(cell.date) : cell.date.getDate()
            color: cell.isToday ? Theme.backgroundColor : Theme.textColor
            opacity: cell.isWeekNumber ? 0.4 : (cell.inMonth ? 1 : 0.35)
            sizeScale: cell.isWeekNumber ? 0.65 : 0.85
          }

          MouseArea {
            id: dayMouse
            anchors.fill: parent
            hoverEnabled: !cell.isWeekNumber
          }
        }
      }
    }
  }
}
