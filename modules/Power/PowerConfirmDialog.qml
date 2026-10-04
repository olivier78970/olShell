import QtQuick
import qs.components
import qs.config
import qs.services

// Confirmation shown before a power action actually runs, placed like the
// power panel it follows (Settings.powerPlacement: against the bar of the
// button that opened it, or centered), sized to its content. Enter or "Confirm" runs the action;
// Escape, "Cancel" or a click outside the dialog cancels it.
ModalPanel {
  id: root

  readonly property string action: PowerMenuState.pendingAction
  // The action being asked about, kept after it is answered so the message
  // (and with it the dialog's size) stays while the dialog animates away.
  property string shownAction: PowerMenuState.pendingAction
  onActionChanged: {
    if (root.action !== "") root.shownAction = root.action
  }
  readonly property var messages: ({
    logout: I18n.tr("power.confirm.logout"),
    restart: I18n.tr("power.confirm.restart"),
    firmware: I18n.tr("power.confirm.firmware"),
    shutdown: I18n.tr("power.confirm.shutdown")
  })

  // Fits its content, a margin around it.
  maxPanelWidth: content.implicitWidth + 2 * 24
  maxPanelHeight: content.implicitHeight + 2 * 16
  placement: Settings.powerPlacement
  anchorItem: PowerPanelState.anchorItem

  open: root.action !== ""
  onCloseRequested: PowerMenuState.cancel()

  onKeyPressed: event => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      PowerMenuState.confirm()
      event.accepted = true
    }
  }

  Column {
    id: content
    anchors.centerIn: parent
    spacing: 20

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.messages[root.shownAction] ?? ""
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      PowerMenuOption {
        label: I18n.tr("common.cancel")
        onClicked: PowerMenuState.cancel()
      }

      PowerMenuOption {
        label: I18n.tr("common.confirm")
        onClicked: PowerMenuState.confirm()
      }
    }
  }
}
