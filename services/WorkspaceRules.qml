pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The workspaces the Hyprland config has a rule for (so most likely keybinds
// too): the bar's workspaces widget flags the others, and the settings panel
// says how many there are.
Singleton {
  id: root

  // Their ids, in the order the config lists them.
  property var configured: []
  // How many workspaces the bar shows: Settings.workspaceCount, or with
  // Settings.workspaceCountFromHyprland, up to the highest one the config
  // sets up (so all of them show, even with gaps in the numbering), within
  // the setting's own limits - the setting still, when the config sets up
  // none.
  readonly property int shownCount: {
    if (!Settings.workspaceCountFromHyprland || root.configured.length === 0) return Settings.workspaceCount
    const [min, max] = Settings.limits.workspaceCount
    return Math.max(min, Math.min(max, Math.max(...root.configured)))
  }

  // Read at start and after each config reload, so adding a rule shows.
  Process {
    id: rulesProcess
    running: true
    command: ["hyprctl", "workspacerules", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.configured = JSON.parse(this.text).map(rule => Number(rule.workspaceString)).filter(id => Number.isInteger(id) && id > 0)
        } catch (e) {}
      }
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded") rulesProcess.running = true
    }
  }
}
