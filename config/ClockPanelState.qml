pragma Singleton

import QtQuick
import Quickshell

// Shared visibility for the clock panel, so the bar's clock widget (on
// whichever screen it's clicked from) and the panel itself - a single
// top-level module shared by every screen's bar, instead of one popup per
// bar - stay in sync.
Singleton {
  id: root

  property bool visible: false
  // The clock widget that opened the panel: the panel reads its position
  // (and screen, see modules/Clock/ClockPanel.qml) to place itself.
  property Item anchorItem: null

  function toggle(item) {
    // Asked again while it is still waiting to open: cancel that.
    if (Panels.cancel(root)) return
    if (root.visible && root.anchorItem === item) {
      root.visible = false
      return
    }
    Panels.open(root, () => {
      root.anchorItem = item
      root.visible = true
    })
  }
}
