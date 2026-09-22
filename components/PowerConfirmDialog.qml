import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Modal confirmation shown before a power action actually runs. It covers
// the whole screen with a dimmed backdrop and takes exclusive keyboard
// focus, so nothing else can be clicked or typed into until the user
// answers: Enter or "Confirmer" runs the action; Escape, "Annuler" or a
// click outside the dialog cancels it.
//
// The backdrop and the dialog are two separate layer-shell surfaces (see
// frameWindow below) so a blur layer rule can target just the dialog - see
// ModalPanel.qml, which this mirrors.
PanelWindow {
  id: root

  readonly property string action: PowerMenuState.pendingAction
  readonly property var messages: ({
    logout: I18n.tr("power.confirm.logout"),
    restart: I18n.tr("power.confirm.restart"),
    shutdown: I18n.tr("power.confirm.shutdown")
  })

  WlrLayershell.layer: WlrLayer.Overlay
  // A distinct namespace from frameWindow's default one (shared with the
  // bar, pills, popups and OSDs, all of which do want to blur).
  WlrLayershell.namespace: "quickshell:backdrop"

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
  // No keyboard focus of its own: frameWindow below takes it instead.
  focusable: false
  // Ignore the bar's reserved exclusive zone so the backdrop covers the
  // whole screen, including the strip behind the top bar.
  exclusionMode: ExclusionMode.Ignore

  // Dimmed backdrop; a click outside the dialog cancels, like clicking
  // outside any other modal dialog. A click actually on the dialog never
  // reaches this MouseArea to begin with - it's a separate, topmost
  // surface - but the bounds check is kept as a safety net against
  // stacking surprises.
  MouseArea {
    anchors.fill: parent
    onClicked: mouse => {
      const insideDialog = mouse.x >= frameWindow.margins.left && mouse.x <= frameWindow.margins.left + dialog.width
        && mouse.y >= frameWindow.margins.top && mouse.y <= frameWindow.margins.top + dialog.height
      if (!insideDialog) PowerMenuState.cancel()
    }

    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: 0.4
    }
  }

  // The actual dialog, its own layer-shell surface on Quickshell's default
  // namespace (like the bar, pills, popups and OSDs, see services/Blur.qml)
  // rather than root's: Hyprland blurs whatever's behind a whole surface,
  // and the dialog used to share the backdrop's, which meant the dim
  // blurred too instead of staying sharp. Centered with explicit margins
  // (rather than left unanchored) so its on-screen geometry is known here,
  // for the bounds check above.
  PanelWindow {
    id: frameWindow

    visible: root.visible
    screen: root.screen

    WlrLayershell.layer: WlrLayer.Overlay
    // Grabs all keyboard input while open, so shortcuts/typing never leak
    // to whatever's behind the dialog.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
      top: true
      left: true
    }
    margins.left: (root.width - dialog.width) / 2
    margins.top: (root.height - dialog.height) / 2
    implicitWidth: dialog.width
    implicitHeight: dialog.height

    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    // Grabbed here, from this window's own visibility, rather than root's:
    // frameWindow's `visible` only mirrors root's a binding tick later, so
    // requesting focus from root's own visibleChanged could fire before
    // this window (and its surface) actually exists yet to grab it.
    onVisibleChanged: {
      if (frameWindow.visible) dialog.forceActiveFocus()
    }

    Rectangle {
      id: dialog
      width: content.implicitWidth + 48
      height: content.implicitHeight + 32
      radius: Theme.radiusFor(height)
      color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
      border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
      border.width: Theme.borderWidth
      focus: true

      Keys.onReturnPressed: PowerMenuState.confirm()
      Keys.onEnterPressed: PowerMenuState.confirm()
      Keys.onEscapePressed: PowerMenuState.cancel()

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
  }
}
