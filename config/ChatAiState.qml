pragma Singleton

import Quickshell

// Shared visibility for the chat AI panel, so its IPC handler and the bar's
// button toggle the same panel instance. The question and answer themselves
// are kept by services/ChatAi.qml, so they outlive the panel.
Singleton {
  id: root

  property bool visible: false
  // The id of the provider picked in the panel, "" for the default one of
  // the settings (see services/ChatAi.qml); kept between openings.
  property string provider: ""
  // The model picked in the panel for each provider, by provider id, in
  // place of its default (the one set in the settings) until the shell
  // restarts; a provider without one asks its default.
  property var models: ({})

  function toggle() {
    // Asked again while it is still waiting to open: cancel that.
    if (Panels.cancel(root)) return
    if (root.visible) {
      root.visible = false
      return
    }
    Panels.open(root, () => root.visible = true)
  }
}
