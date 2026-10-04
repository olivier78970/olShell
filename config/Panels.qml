pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell

// Opens the full-screen panels one at a time. They all grab the keyboard, so
// opening one closes the others; and since a panel takes a moment to
// animate away (Theme.animationDuration), the new one waits until every other
// panel has gone, however it was closed (by this, by a click outside it, by
// Escape), so the two never show together. Every panel's State opens through
// open() below.
Singleton {
  id: root

  // Every panel's State, each with a `visible` property.
  readonly property var all: [
    WallpaperPanelState, ThemePanelState, LauncherState, SettingsPanelState,
    NotificationCenterState, PowerPanelState, ClockPanelState, ShortcutsPanelState,
    AppSwitcherState, NotificationActionsState, ChatAiState
  ]

  // When each panel (by its place in `all`) last closed, in milliseconds.
  property var closedAt: ({})

  // What to run once the other panels have gone: it sets the panel's own
  // properties and shows it.
  property var pending: null
  // The panel `pending` opens.
  property var pendingPanel: null

  // Notes when a panel closes.
  Instantiator {
    model: root.all

    Connections {
      required property var modelData
      required property int index

      target: modelData

      function onVisibleChanged() {
        if (!modelData.visible) root.closedAt[index] = Date.now()
      }
    }
  }

  // Closes every panel but `panel`, then runs `show` (which makes `panel`
  // visible) once the others have animated away: at once if none was open
  // lately. A later call replaces one still waiting.
  function open(panel, show) {
    let wait = 0
    root.all.forEach((other, index) => {
      if (other === panel) return
      if (other.visible) other.visible = false
      const closed = root.closedAt[index]
      if (closed !== undefined) wait = Math.max(wait, closed + Theme.animationDuration - Date.now())
    })
    delay.stop()
    root.pendingPanel = null
    if (wait <= 0) {
      root.pending = null
      show()
      return
    }
    root.pending = show
    root.pendingPanel = panel
    delay.interval = wait
    delay.restart()
  }

  // How long after a panel closed a toggle of it still counts as the click
  // that closed it, in milliseconds.
  readonly property int clickWindow: 300

  // Called first by a panel's toggle(), true when there is nothing left to do:
  // - its opening was still waiting for another panel to go, and a second
  //   click on its button cancels that;
  // - it closed a moment ago, the click on its button having been taken by
  //   the bar's click catcher (which closes it on the press) and then
  //   reaching the button too, which would open it again.
  function cancel(panel) {
    if (root.pendingPanel === panel && delay.running) {
      delay.stop()
      root.pending = null
      root.pendingPanel = null
      return true
    }
    const closed = root.closedAt[root.all.indexOf(panel)]
    return closed !== undefined && !panel.visible && Date.now() - closed < root.clickWindow
  }

  Timer {
    id: delay
    onTriggered: {
      const show = root.pending
      root.pending = null
      root.pendingPanel = null
      if (show) show()
    }
  }
}
