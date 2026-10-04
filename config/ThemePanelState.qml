pragma Singleton

import QtQuick
import Quickshell

// Shared visibility for the theme panel, so both the bar's trigger widget
// and the IPC handler can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false
  // The bar widget that opened the panel, which it opens against (see
  // ModalPanel's `attached`); null when opened by IPC, which centers it
  // along the focused screen's bar instead.
  property Item anchorItem: null

  function toggle(item) {
    // Asked again while it is still waiting to open: cancel that.
    if (Panels.cancel(root)) return
    const anchor = item ?? null
    // Clicked from another screen's bar while open: move there instead.
    if (root.visible && anchor !== null && root.anchorItem !== null && root.anchorItem !== anchor) {
      root.anchorItem = anchor
      return
    }
    Panels.open(root, () => {
      root.anchorItem = anchor
      root.visible = !root.visible
    })
  }
}
