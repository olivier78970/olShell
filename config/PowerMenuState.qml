pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Shared state for the power confirmation dialog. PowerPanel sets
// `pendingAction` when an action is picked; PowerConfirmDialog reads
// it to decide what to show and calls confirm()/cancel().
Singleton {
  id: root

  // "" | "logout" | "restart" | "firmware" | "shutdown"
  property string pendingAction: ""

  // Whether the confirmation dialog is up, so Panels can close it before it
  // opens another panel (setting it false cancels the request).
  property bool visible: false
  onPendingActionChanged: root.visible = root.pendingAction !== ""
  onVisibleChanged: if (!root.visible) root.cancel()

  // The action waiting for the power panel to finish animating away.
  property string requested: ""

  // Asks to confirm `action`, once the power panel (closed just before) has
  // animated away, so the two never show together.
  function request(action) {
    root.requested = action
    requestTimer.restart()
  }

  function cancel() {
    requestTimer.stop()
    root.pendingAction = ""
  }

  function confirm() {
    const action = root.pendingAction
    root.pendingAction = ""
    if (action === "logout") {
      Hyprland.dispatch("hl.dsp.exit()")
    } else if (action === "restart") {
      restartProcess.running = true
    } else if (action === "firmware") {
      firmwareProcess.running = true
    } else if (action === "shutdown") {
      shutdownProcess.running = true
    }
  }

  // Suspends at once (it needs no confirmation).
  function suspend() {
    suspendProcess.running = true
  }

  Timer {
    id: requestTimer
    interval: Theme.animationDuration
    onTriggered: root.pendingAction = root.requested
  }

  Process {
    id: restartProcess
    command: ["systemctl", "reboot"]
  }

  Process {
    id: shutdownProcess
    command: ["systemctl", "poweroff"]
  }

  // Restarts into the firmware's (UEFI's) setup screen.
  Process {
    id: firmwareProcess
    command: ["systemctl", "reboot", "--firmware-setup"]
  }

  Process {
    id: suspendProcess
    command: ["systemctl", "suspend"]
  }
}
