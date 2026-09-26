pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Points Hyprland's QS_CONFIG_PATH at the folder this shell runs from, so the
// shortcuts' `qs ipc` calls reach the shell that is running (a checkout or
// the deployed copy) rather than the one ~/.config/hypr/env.lua names. Set
// once the shell has started, and again after every Hyprland config reload,
// which re-runs env.lua and so puts that one back.
Singleton {
  id: root

  // This shell's folder, without the trailing slash.
  readonly property string path: Quickshell.shellPath("").replace(/\/+$/, "")

  function apply() {
    // The path goes through JSON.stringify so it is a valid Lua string.
    process.command = ["hyprctl", "eval", `hl.env("QS_CONFIG_PATH", ${JSON.stringify(root.path)})`]
    process.running = true
  }

  // A Process started while the shell is loading silently does nothing, so
  // the first one waits a moment.
  Timer {
    interval: 1000
    running: true
    onTriggered: root.apply()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded") root.apply()
    }
  }

  Process {
    id: process
  }
}
