import QtQuick
import qs.components
import qs.config
import qs.services

// Printer with the number of print jobs waiting or printing to its right
// (under it on a side bar), shown only while the queue isn't empty unless
// Settings.printerAlwaysShown (see services/Printers.qml), and in the warning
// color while a printer with jobs is stopped. A left click runs its action
// (Settings.printerAction, system-config-printer by default); hovering it
// shows the printers (with whether each is idle, printing or stopped) and
// the jobs;
// a right click opens a menu showing the same, with buttons to suspend (or
// resume) and cancel each job, and one on the jobs heading cancelling them
// all (after a second click to confirm).
Item {
  id: root

  // Shown always with Settings.printerAlwaysShown, else while there are jobs
  // or its menu is open (so cancelling the last job doesn't pull the menu
  // away under the pointer).
  readonly property bool present: Settings.printerAlwaysShown || Printers.jobs.length > 0 || menu.open
  readonly property bool menuOpen: menu.open
  readonly property color tint: Printers.stalled ? Theme.warningColor : Theme.textColor

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  BarStack {
    id: content
    anchors.centerIn: parent
    gap: 6

    BarText {
      text: Printers.stalled ? "󰐬" : "󰐪"
      color: root.tint
    }

    // The number of jobs.
    BarText {
      visible: Printers.jobs.length > 0
      text: Printers.jobs.length
      sizeScale: Theme.barFigureScale
      color: root.tint
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      tooltip.dismiss()
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else {
        menu.open = false
        WidgetActions.run("printer")
      }
    }
    onEntered: tooltip.hoverEntered()
    onExited: tooltip.hoverExited()
  }

  // A job's size, in kilobytes or megabytes.
  function size(kilobytes) {
    return kilobytes >= 1024 ? I18n.tr("printer.size.mb", (kilobytes / 1024).toFixed(1)) : I18n.tr("printer.size.kb", kilobytes)
  }

  // What a job is doing: printing, waiting its turn, held or stopped (with
  // what its printer says, when it says something).
  function status(job) {
    const printer = Printers.printer(job.printer)
    if (job.state === 6 || printer?.state === 5) return printer?.message ? I18n.tr("printer.state.stoppedBecause", printer.message) : I18n.tr("printer.state.stopped")
    if (job.state === 5) return I18n.tr("printer.state.printing")
    if (job.state === 4) return I18n.tr("printer.state.held")
    return I18n.tr("printer.state.waiting")
  }

  // A printer's icon, name and state, with CUPS' reason under it when it's
  // stopped.
  function printerLine(printer) {
    const state = printer.state === 5 ? "stopped" : printer.state === 4 ? "printing" : "idle"
    return (printer.state === 5 ? "󰐬  " : "󰐪  ") + I18n.tr("printer.printerState." + state, printer.info)
      + (printer.state === 5 && printer.message ? "\n" + printer.message : "")
  }

  // A job's printer, only when there are several to tell apart.
  function printerOf(job) {
    return Printers.printers.length > 1 ? Printers.printer(job.printer)?.info ?? job.printer : ""
  }

  // A job's line: its document, size, status and (with several printers)
  // printer.
  function jobLine(job) {
    return [job.name !== "" ? job.name : I18n.tr("printer.untitled", job.id), root.size(job.size), root.status(job), root.printerOf(job)]
      .filter(part => part !== "").join("  ·  ")
  }

  // A line of text in the menu, lined up with the entries' labels.
  component PopupMenuText: ThemedText {
    leftPadding: 12
    rightPadding: 12
    bottomPadding: 2
  }

  // A line of the menu with text at the left and buttons (its children) at
  // the right end, as far right as the menu is wide, so the buttons of every
  // line stand in columns. `momentary` is a child shown only for a moment (a
  // confirmation): it doesn't count in the line's width, so the menu keeps its
  // width and the text is shortened (with "…") to make room for it.
  component ButtonLine: Item {
    id: line

    property string text: ""
    property color textColor: Theme.textColor
    property real textScale: 0.85
    property real topPadding: 0
    property Item momentary: null
    default property alias buttons: buttonRow.data

    implicitWidth: lineText.implicitWidth + 8 + buttonRow.width - (line.momentary?.visible ? line.momentary.width : 0)
    implicitHeight: Math.max(lineText.implicitHeight, buttonRow.height) + line.topPadding

    ThemedText {
      id: lineText
      y: line.topPadding + (line.height - line.topPadding - height) / 2
      width: Math.min(implicitWidth, buttonRow.x - 8)
      leftPadding: 12
      elide: Text.ElideRight
      text: line.text
      color: line.textColor
      sizeScale: line.textScale
    }

    Row {
      id: buttonRow
      y: line.topPadding + (line.height - line.topPadding - height) / 2
      x: Math.max(12, (line.parent?.width ?? 0) - width)
    }
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    PopupTitle {
      text: I18n.tr("settings.widget.printer")
      inMenu: true
    }

    // The same contents as the hover popup, lined up with the entries'
    // labels: the printers, each with its state...
    PopupMenuText {
      visible: Printers.printers.length === 0
      text: I18n.tr(Printers.error !== "" ? "printer.error." + Printers.error : "printer.noPrinter")
    }

    Repeater {
      model: Printers.printers

      PopupMenuText {
        required property var modelData
        text: root.printerLine(modelData)
        color: modelData.state === 5 ? Theme.warningColor : Theme.textColor
      }
    }

    // ...then the jobs, under a heading with a button cancelling them all
    // (while there are some). It asks for a second click first: its first
    // click shows "Cancel all jobs?" beside it for a few seconds.
    ButtonLine {
      id: jobsLine

      property bool confirming: false

      visible: Printers.printers.length > 0
      text: Printers.jobs.length > 0 ? I18n.tr("printer.jobs", Printers.jobs.length) : I18n.tr("printer.none")
      textColor: Theme.accentColor
      textScale: 1
      topPadding: 4

      momentary: cancelAllConfirm

      ThemedText {
        id: cancelAllConfirm
        visible: jobsLine.confirming
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr("printer.cancelAllConfirm")
        sizeScale: 0.85
        color: Theme.warningColor
      }

      IconButton {
        visible: Printers.jobs.length > 0
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰅖"
        sizeScale: 1
        color: jobsLine.confirming ? Theme.warningColor : Theme.textColor
        onClicked: {
          if (!jobsLine.confirming) {
            jobsLine.confirming = true
            confirmTimer.restart()
            return
          }
          jobsLine.confirming = false
          Printers.cancelAll()
        }
      }

      Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: jobsLine.confirming = false
      }

      Connections {
        target: menu

        function onOpenChanged() {
          if (!menu.open) jobsLine.confirming = false
        }
      }
    }

    // The jobs, oldest first, each with a button suspending it (or letting
    // it print again once suspended; not while it prints, which CUPS can't
    // suspend) and one cancelling it, which asks for a second click first
    // (its first click shows "Cancel?" beside it for a few seconds).
    Repeater {
      model: Printers.jobs

      ButtonLine {
        id: jobRow

        required property var modelData
        readonly property bool held: jobRow.modelData.state === 4
        // Whether its cross was clicked once, for a few seconds: a second
        // click cancels the job.
        property bool confirming: false

        text: root.jobLine(jobRow.modelData)
        momentary: cancelConfirm

        IconButton {
          anchors.verticalCenter: parent.verticalCenter
          enabled: jobRow.modelData.state === 3 || jobRow.held
          icon: jobRow.held ? "󰐊" : "󰏤"
          sizeScale: 1
          onClicked: jobRow.held ? Printers.release(jobRow.modelData.id) : Printers.hold(jobRow.modelData.id)
        }

        // Between the suspend button and the cross, right beside the cross.
        ThemedText {
          id: cancelConfirm
          visible: jobRow.confirming
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("printer.cancelConfirm")
          sizeScale: 0.85
          color: Theme.warningColor
        }

        IconButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰅖"
          sizeScale: 1
          color: jobRow.confirming ? Theme.warningColor : Theme.textColor
          onClicked: {
            if (!jobRow.confirming) {
              jobRow.confirming = true
              jobConfirmTimer.restart()
              return
            }
            jobRow.confirming = false
            Printers.cancel(jobRow.modelData.id)
          }
        }

        Timer {
          id: jobConfirmTimer
          interval: 3000
          onTriggered: jobRow.confirming = false
        }

        Connections {
          target: menu

          function onOpenChanged() {
            if (!menu.open) jobRow.confirming = false
          }
        }
      }
    }
  }

  // The printers, each with its state, then the jobs with their printer,
  // size and status.
  HoverPopup {
    id: tooltip
    anchorItem: root
    alignCenter: true
    showWhen: !menu.open

    PopupTitle {
      text: I18n.tr("settings.widget.printer")
    }

    // Said instead of the printers when there is none (or CUPS can't say).
    ThemedText {
      visible: Printers.printers.length === 0
      text: I18n.tr(Printers.error !== "" ? "printer.error." + Printers.error : "printer.noPrinter")
    }

    Repeater {
      model: Printers.printers

      ThemedText {
        required property var modelData
        text: root.printerLine(modelData)
        color: modelData.state === 5 ? Theme.warningColor : Theme.textColor
      }
    }

    ThemedText {
      visible: Printers.printers.length > 0
      text: Printers.jobs.length > 0 ? I18n.tr("printer.jobs", Printers.jobs.length) : I18n.tr("printer.none")
      topPadding: 4
      color: Theme.accentColor
    }

    Repeater {
      model: Printers.jobs

      ThemedText {
        required property var modelData
        text: root.jobLine(modelData)
        sizeScale: 0.85
      }
    }
  }
}
