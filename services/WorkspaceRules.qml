pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The workspaces the Hyprland config has a rule for (so most likely keybinds
// too): the bar's workspaces widget flags the others, and the settings panel
// says how many there are. Its `workspaces` IPC calls go to a workspace by
// its place on the focused monitor (focus 1 is the first one bound to it),
// so one shortcut serves every monitor.
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

  // The workspace ids the config binds to the monitor `name`, in order: what
  // the `workspaces` IPC calls count in. With no rule for that monitor, every
  // id stands for itself (so the calls behave like plain workspace numbers).
  function boundTo(name) {
    return Object.keys(root.monitorOf).map(Number).filter(id => root.monitorOf[id] === name).sort((a, b) => a - b)
  }

  // The id of the `place`-th workspace (from 1) of the focused monitor, or 0
  // when that monitor has fewer.
  function idAt(place) {
    const ids = root.boundTo(Hyprland.focusedMonitor?.name ?? "")
    if (ids.length === 0) return place > 0 ? place : 0
    return place >= 1 && place <= ids.length ? ids[place - 1] : 0
  }

  IpcHandler {
    target: "workspaces"

    // Goes to the n-th workspace of the focused monitor.
    function focus(place: int): void {
      const id = root.idAt(place)
      if (id > 0) Hyprland.dispatch("hl.dsp.focus({workspace=" + id + "})")
    }

    // Moves the active window to the n-th workspace of the focused monitor.
    function moveWindow(place: int): void {
      const id = root.idAt(place)
      if (id > 0) Hyprland.dispatch("hl.dsp.window.move({workspace=" + id + "})")
    }

    // The focused monitor's workspace ids, in the order the calls count them,
    // as JSON (empty when the config binds none to it).
    function list(): string {
      return JSON.stringify(root.boundTo(Hyprland.focusedMonitor?.name ?? ""))
    }
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
