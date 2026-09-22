pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Shared state for the power confirmation dialog. PowerPanel sets
// `pendingAction` when an action is picked; PowerConfirmDialog reads
// it to decide what to show and calls confirm()/cancel().
Singleton {
  id: root

  // "" | "logout" | "restart" | "shutdown"
  property string pendingAction: ""

  function request(action) {
    root.pendingAction = action
  }

  function cancel() {
    root.pendingAction = ""
  }

  function confirm() {
    const action = root.pendingAction
    root.pendingAction = ""
    if (action === "logout") {
      Hyprland.dispatch("hl.dsp.exit()")
    } else if (action === "restart") {
      restartProcess.running = true
    } else if (action === "shutdown") {
      shutdownProcess.running = true
    }
  }

  Process {
    id: restartProcess
    command: ["systemctl", "reboot"]
  }

  Process {
    id: shutdownProcess
    command: ["systemctl", "poweroff"]
  }
}
