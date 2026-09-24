pragma Singleton

import QtQuick
import Quickshell

// Every screen's bar keeps an empty slot (see Bar.qml's panelSlot) that a
// panel attached to it - the clock and notification panels, the theme and
// wallpaper pickers - moves its frame into while it's open. Drawn inside the
// bar's own surface, bar and panel are blurred together, once: as a
// separate surface on top, the panel's blur also picked up the bar's own
// fill right under it, which left the panel visibly darker along the seam.
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
}
