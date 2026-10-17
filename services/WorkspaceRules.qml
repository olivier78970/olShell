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
  // The monitor name each rule binds its workspace to, by workspace id
  // (only the rules with a monitor).
  property var monitorOf: ({})
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

  // The workspace ids the bar of the monitor `name` shows when workspaces are
  // per monitor: those bound to it plus the ones bound to no monitor, which
  // any screen can show. Following the Hyprland config, that is all of them
  // up to shownCount; otherwise the first ones, as many as the monitor's
  // count (Settings.workspaceCountFor()).
  function idsForMonitor(name) {
    const follow = Settings.workspaceCountFromHyprland && root.configured.length > 0
    const last = follow ? root.shownCount : Settings.limits.workspaceCount[1]
    const ids = []
    for (let id = 1; id <= last; id++) {
      const monitor = root.monitorOf[id]
      if (monitor === undefined || monitor === name) ids.push(id)
    }
    return follow ? ids : ids.slice(0, Settings.workspaceCountFor(name))
  }

  // Read at start and after each config reload, so adding a rule shows.
  Process {
    id: rulesProcess
    running: true
    command: ["hyprctl", "workspacerules", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const rules = JSON.parse(this.text)
          root.configured = rules.map(rule => Number(rule.workspaceString)).filter(id => Number.isInteger(id) && id > 0)
          const monitors = {}
          for (const rule of rules) {
            const id = Number(rule.workspaceString)
            if (Number.isInteger(id) && id > 0 && rule.monitor) monitors[id] = rule.monitor
          }
          root.monitorOf = monitors
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
