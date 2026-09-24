pragma Singleton

import QtQuick
import Quickshell

// Every screen's bar keeps an empty slot (see Bar.qml's panelSlot) that a
// panel attached to it - the clock and notification panels, the theme and
// wallpaper pickers - moves its frame into while it's open. Drawn inside the
// bar's own surface, bar and panel are blurred together, once: as a
// separate surface on top, the panel's blur also picked up the bar's own
// fill right under it, which left the panel visibly darker along the seam.
// The widgets' popups and menus (PopupMenu) are drawn in the bar the same
// way, in its popup layer.
Singleton {
  id: root

  // The slots of the bars currently up, one per screen.
  property var slots: []

  function register(slot) {
    root.slots = root.slots.concat([slot])
  }

  function unregister(slot) {
    root.slots = root.slots.filter(s => s !== slot)
  }

  // The slot of `screen`'s bar, or null.
  function slotFor(screen) {
    if (!screen) return null
    return root.slots.find(slot => slot.screen === screen) ?? null
  }

  // The popup layers of the bars currently up, one per screen.
  property var popupLayers: []

  function registerPopupLayer(layer) {
    root.popupLayers = root.popupLayers.concat([layer])
  }

  function unregisterPopupLayer(layer) {
    root.popupLayers = root.popupLayers.filter(l => l !== layer)
  }

  // The popup layer of `screen`'s bar, or null.
  function popupLayerFor(screen) {
    if (!screen) return null
    return root.popupLayers.find(layer => layer.screen === screen) ?? null
  }
}
