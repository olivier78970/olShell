pragma Singleton

import Quickshell

// Shared visibility for the keyboard shortcuts panel, so its IPC handler and
// anything else can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

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
