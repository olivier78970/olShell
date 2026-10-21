pragma Singleton

import Quickshell

// Shared visibility for the emoji panel, so its IPC handler and the bar's
// button toggle the same panel instance, and what the panel keeps between
// openings (the group shown, the emoji copied lately).
Singleton {
  id: root

  property bool visible: false
  // The group the panel shows: "recent" or one of EmojiPanel.qml's groups.
  property string group: "smileys"
  // The emoji copied lately, the newest first, until the shell restarts.
  property var recent: []
  // How many emoji `recent` keeps.
  readonly property int recentMax: 40

  function toggle() {
    // Asked again while it is still waiting to open: cancel that.
    if (Panels.cancel(root)) return
    if (root.visible) {
      root.visible = false
      return
    }
    Panels.open(root, () => root.visible = true)
  }

  // Copies `emoji` to the clipboard and puts it first in `recent`.
  function copy(emoji) {
    Quickshell.clipboardText = emoji
    root.recent = [emoji].concat(root.recent.filter(other => other !== emoji)).slice(0, root.recentMax)
  }
}
