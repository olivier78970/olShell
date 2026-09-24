import QtQuick
import Quickshell.Io
import qs.components
import qs.config

// Screen-centered power panel (no frame: just the three buttons, over the
// dimmed screen) with the three actions (log out, restart, shut
// down), toggled from the bar's power button or from outside via:
//   quickshell -p . ipc call power toggle
// Left/Right (or Tab) move between the actions, Enter or a click picks one,
// Escape or a click outside closes. Picking one closes the panel and asks for
// confirmation (PowerConfirmDialog) before anything runs.
ModalPanel {
  id: root

  readonly property var actions: [
    { id: "logout", icon: "󰍃", label: I18n.tr("power.logout") },
    { id: "restart", icon: "󰜉", label: I18n.tr("power.restart") },
    { id: "shutdown", icon: "󰐥", label: I18n.tr("power.shutdown") }
  ]
  property int current: 0

  maxPanelWidth: 452
  maxPanelHeight: 120
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
    PowerMenuState.request(id)
  }

  onKeyPressed: event => {
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
      root.current = (root.current + root.actions.length - 1) % root.actions.length
      event.accepted = true
    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
      root.current = (root.current + 1) % root.actions.length
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      root.pick(root.actions[root.current].id)
      event.accepted = true
    }
  }

  // `power toggle` opens or closes the panel; the others go straight to the
  // confirmation for that action.
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
  }

  Row {
    anchors.centerIn: parent
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
