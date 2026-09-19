import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Modal confirmation shown before a power action actually runs. It covers
// the whole screen with a dimmed backdrop and takes exclusive keyboard
// focus, so nothing else can be clicked or typed into until the user
// answers: Enter or "Confirmer" runs the action; Escape, "Annuler" or a
// click outside the dialog cancels it.
PanelWindow {
  id: root

  readonly property string action: PowerMenuState.pendingAction
  readonly property var messages: ({
    logout: "Se déconnecter ?",
    restart: "Redémarrer l'ordinateur ?",
    shutdown: "Éteindre l'ordinateur ?"
  })

  WlrLayershell.layer: WlrLayer.Overlay
  // Grabs all keyboard input while open, so shortcuts/typing never leak
  // to whatever's behind the dialog.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  // Fills the whole screen (rather than just sizing to the dialog) so the
  // backdrop below covers everything and clicks outside the dialog are
  // swallowed instead of reaching windows behind it.
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  visible: root.action !== ""
  color: "transparent"
  aboveWindows: true
  focusable: true
  // Ignore the bar's reserved exclusive zone so the backdrop covers the
  // whole screen, including the strip behind the top bar.
  exclusionMode: ExclusionMode.Ignore

  onVisibleChanged: {
    if (root.visible) dialog.forceActiveFocus()
  }

  // Dimmed backdrop; a click outside the dialog cancels, like clicking
  // outside any other modal dialog.
  MouseArea {
    anchors.fill: parent
    onClicked: mouse => {
      const point = mapToItem(dialog, mouse.x, mouse.y)
      const insideDialog = point.x >= 0 && point.x <= dialog.width && point.y >= 0 && point.y <= dialog.height
      if (!insideDialog) PowerMenuState.cancel()
    }

    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: 0.4
    }
  }

  Rectangle {
    id: dialog
    anchors.centerIn: parent
    width: content.implicitWidth + 48
    height: content.implicitHeight + 32
    radius: Theme.radiusFor(height)
    color: Theme.pillColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth
    opacity: Theme.widgetOpacity
    focus: true

    Keys.onReturnPressed: PowerMenuState.confirm()
    Keys.onEnterPressed: PowerMenuState.confirm()
    Keys.onEscapePressed: PowerMenuState.cancel()

    // Swallow clicks on the dialog itself so they don't fall through to
    // the backdrop's MouseArea and cancel it.
    MouseArea {
      anchors.fill: parent
    }

    Column {
      id: content
      anchors.centerIn: parent
      spacing: 20

      ThemedText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.messages[root.action] ?? ""
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        PowerMenuOption {
          label: "Annuler"
          onClicked: PowerMenuState.cancel()
        }

        PowerMenuOption {
          label: "Confirmer"
          onClicked: PowerMenuState.confirm()
        }
      }
    }
  }
}
