import QtQuick
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// Screen-centered power panel (no frame: just the buttons, over the dimmed
// screen) with the power actions (lock, suspend, log out, restart, restart
// into the UEFI setup, shut down), toggled from the bar's power button or
// from outside via:
//   quickshell -p . ipc call power toggle
// The buttons are on two rows of three. The arrows move between them (Tab
// and Shift+Tab go through them in order), Enter or a click picks one,
// Escape or a click outside closes. Picking one closes the panel; lock and
// suspend then happen at once, the others ask for confirmation
// (PowerConfirmDialog) before anything runs.
ModalPanel {
  id: root

  readonly property var actions: [
    { id: "lock", icon: "󰌾", label: I18n.tr("power.lock") },
    { id: "suspend", icon: "󰒲", label: I18n.tr("power.suspend") },
    { id: "logout", icon: "󰍃", label: I18n.tr("power.logout") },
    { id: "restart", icon: "󰜉", label: I18n.tr("power.restart") },
    { id: "firmware", icon: "󰍛", label: I18n.tr("power.firmware") },
    { id: "shutdown", icon: "󰐥", label: I18n.tr("power.shutdown") }
  ]
  // The buttons per row: the six actions make two rows of three.
  readonly property int columns: 3
  property int current: 0

  maxPanelWidth: 452
  maxPanelHeight: 256
  framed: false
  // The screen darkens behind it, the only panel that does: shutting down or
  // logging out is worth that pause.
  dimmed: true
  dimOpacity: 0.65

  open: PowerPanelState.visible
  onCloseRequested: PowerPanelState.visible = false
  onOpened: root.current = 0

  function pick(id) {
    PowerPanelState.visible = false
    // Nothing to lose in these two: no confirmation. (Suspending locks the
    // screen first if the idle daemon is set to, as hypridle's
    // before_sleep_cmd does.)
    if (id === "lock") Lock.lock()
    else if (id === "suspend") PowerMenuState.suspend()
    else PowerMenuState.request(id)
  }

  onKeyPressed: event => {
    const count = root.actions.length
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
      root.current = (root.current + count - 1) % count
      event.accepted = true
    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
      root.current = (root.current + 1) % count
      event.accepted = true
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
      // Up and Down switch rows, keeping the column.
      root.current = (root.current + root.columns) % count
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      root.pick(root.actions[root.current].id)
      event.accepted = true
    }
  }

  // `power toggle` opens or closes the panel; the others do what its buttons
  // do (suspend at once, the rest through the confirmation).
  IpcHandler {
    target: "power"

    function toggle(): void {
      PowerPanelState.toggle()
    }

    function logout(): void {
      root.pick("logout")
    }

    function restart(): void {
      root.pick("restart")
    }

    function shutdown(): void {
      root.pick("shutdown")
    }

    function suspend(): void {
      root.pick("suspend")
    }

    function firmware(): void {
      root.pick("firmware")
    }
  }

  Grid {
    anchors.centerIn: parent
    columns: root.columns
    spacing: 16

    Repeater {
      model: root.actions

      Rectangle {
        id: card

        required property var modelData
        required property int index
        readonly property bool selected: card.index === root.current

        width: 140
        height: 120
        radius: Theme.radiusFor(height)
        color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
        border.color: Theme.fade(card.selected ? Theme.accentColor : Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
        border.width: card.selected ? 2 : Theme.borderWidth

        Column {
          anchors.centerIn: parent
          spacing: 10

          ThemedText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.modelData.icon
            sizeScale: 2.4
            color: card.selected ? Theme.accentColor : Theme.textColor
          }

          ThemedText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.modelData.label
            color: card.selected ? Theme.accentColor : Theme.textColor
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.current = card.index
          onClicked: root.pick(card.modelData.id)
        }
      }
    }
  }
}
