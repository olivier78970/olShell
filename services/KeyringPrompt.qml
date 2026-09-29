pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Makes way for GNOME Keyring's password prompt (gcr-prompter), which opens
// when a key is saved to or read from a locked keyring (the chat AI's API
// keys, see services/ChatAi.qml). It is an ordinary window, and the shell's
// panels are overlays over every window that hold the keyboard: under one,
// the prompt could be neither seen nor typed in, and what asked for the key
// waited. So while a prompt is open, the open panel steps aside and the
// prompt gets the keyboard; the panel comes back once the last prompt has
// closed.
Singleton {
  id: root

  // The window classes of the prompts to make way for.
  readonly property var promptClasses: ["gcr-prompter"]

  // The prompts open, by Hyprland window address (without 0x).
  property var prompts: []
  // Whether one is open.
  readonly property bool active: root.prompts.length > 0

  // The panels' states, each with a `visible` the panel follows.
  readonly property var panelStates: [LauncherState, SettingsPanelState, ChatAiState, ShortcutsPanelState, ThemePanelState,
    WallpaperPanelState, PowerPanelState, ClockPanelState, NotificationCenterState, NotificationActionsState, AppSwitcherState]
  // The panel put aside for the prompts, to bring back after them (null for
  // none).
  property var hidden: null

  function promptOpened(address) {
    root.prompts = root.prompts.concat([address])
    if (root.hidden === null) {
      root.hidden = root.panelStates.find(state => state.visible) ?? null
      if (root.hidden === SettingsPanelState) {
        // Kept built while hidden, and back where it was (as for the color
        // picker).
        SettingsPanelState.resuming = true
      }
      if (root.hidden !== null) root.hidden.visible = false
    }
    // A tick later, once the panel has let go of the keyboard.
    Qt.callLater(() => Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:0x" + address) + " })"))
  }

  function promptClosed(address) {
    if (!root.prompts.includes(address)) return
    root.prompts = root.prompts.filter(other => other !== address)
    if (root.active || root.hidden === null) return
    const state = root.hidden
    root.hidden = null
    state.visible = true
  }

  Connections {
    target: Hyprland

    // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE and closewindow>>ADDRESS.
    function onRawEvent(event) {
      if (event.name === "openwindow") {
        const fields = event.data.split(",")
        if (root.promptClasses.includes(fields[2])) root.promptOpened(fields[0])
      } else if (event.name === "closewindow") {
        root.promptClosed(event.data)
      }
    }
  }
}
