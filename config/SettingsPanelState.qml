pragma Singleton

import Quickshell

// Shared visibility for the settings panel, so the IPC handler (and any
// future bar button) can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false
  // Set while the panel is hidden only for a moment (to pick a color from the
  // screen): it stays built then (see modules/Settings/SettingsModule.qml),
  // and opens back where it was instead of on its first row.
  property bool resuming: false
  // The category and tab last shown. The panel is built anew each time it
  // opens, so it keeps them here to open on them again.
  property int category: 0
  property int tab: 0
  // The widget picked in the Bar widgets category's Widgets tab: the id of its page.
  property string widgetPage: "widgetWorkspaces"

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
