pragma Singleton

import Quickshell

// Shared state of the notification actions panel, so the settings panel, the
// notification center and its IPC handler can open it - on its list of rules,
// or straight on a new rule made from a notification.
Singleton {
  id: root

  property bool visible: false
  // A rule to edit as the panel opens (a new one, made from a notification),
  // or null for the list.
  property var draft: null
  // Opened from the settings panel: closing it goes back there.
  property bool fromSettings: false

  // Opens the panel on the list of rules.
  function open(fromSettings) {
    Panels.open(root, () => {
      root.draft = null
      root.fromSettings = fromSettings === true
      root.visible = true
    })
  }

  // Opens the panel on a new rule, filled in from `notification`.
  function openFor(notification) {
    Panels.open(root, () => {
      root.draft = {
        app: notification.appName ?? "",
        appMode: "is",
        summary: notification.summary ?? "",
        summaryMode: "is",
        body: notification.body ?? "",
        bodyMode: "starts"
      }
      root.fromSettings = false
      root.visible = true
    })
  }

  function toggle() {
    // Asked again while it is still waiting to open: cancel that.
    if (Panels.cancel(root)) return
    if (root.visible) root.close()
    else root.open(false)
  }

  function close() {
    root.visible = false
    if (root.fromSettings) SettingsPanelState.visible = true
    root.fromSettings = false
  }
}
