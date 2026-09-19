pragma Singleton

import Quickshell
import Quickshell.Io

// Caps Lock and Num Lock state, shared by every consumer. A helper script
// (scripts/lock-keys-watch.py) reads the keyboards' lock LEDs and prints a
// line whenever one changes; `changed` fires for each later change (not for
// the state found at startup), naming the key and its new state.
Singleton {
  id: root

  property bool capsLock: false
  property bool numLock: false
  // False until the first line arrives, so the startup state isn't
  // announced as a change.
  property bool ready: false

  signal changed(string key, bool on)

  Process {
    running: true
    command: ["python3", Quickshell.shellPath("scripts/lock-keys-watch.py")]

    stdout: SplitParser {
      onRead: line => {
        const parts = line.trim().split(" ")
        if (parts.length !== 2) return
        const caps = parts[0] === "1"
        const num = parts[1] === "1"
        const capsChanged = caps !== root.capsLock
        const numChanged = num !== root.numLock
        root.capsLock = caps
        root.numLock = num
        if (!root.ready) {
          root.ready = true
          return
        }
        if (capsChanged) root.changed("caps", caps)
        if (numChanged) root.changed("num", num)
      }
    }
  }
}
