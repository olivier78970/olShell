pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Syncs Hyprland's window look with the shell's settings while
// Settings.windowsSync is on: the windows' border width and corner radius
// (their own, or the shell's border width and widget radius), the gaps
// between windows and around them, and the opacity of the focused window and
// of the others. They are set live with `hl.config()`, replacing the
// Hyprland config's values while the sync is on, and set again after every
// config reload (which puts the config's back). Turning the sync off reloads
// the Hyprland config, so its own values come back at once; the services
// that set things of their own at run time (blur, QS_CONFIG_PATH, workspace
// rules) set them again on that reload.
//
// It also knows Hyprland's gaps_out, which the bar needs (see Bar.qml's
// exclusiveZone): read at startup and after each reload, and followed live
// while synced.
Singleton {
  id: root

  readonly property bool active: Settings.windowsSync

  // The values sent to Hyprland.
  readonly property int borderSize: Settings.windowBorderSame ? Settings.borderWidth : Settings.windowBorderWidth
  readonly property int rounding: Settings.windowRoundingSame ? Settings.radius : Settings.windowRounding

  // Hyprland's gaps_out as top, right, bottom, left.
  property var gapsOut: [0, 0, 0, 0]

  // As the Lua table hl.config() takes.
  readonly property string options: `{ general = { border_size = ${root.borderSize}, gaps_in = ${Settings.windowGapsIn}, gaps_out = ${Settings.windowGapsOut} }, decoration = { rounding = ${root.rounding}, active_opacity = ${Settings.windowActiveOpacity}, inactive_opacity = ${Settings.windowInactiveOpacity} } }`

  // Settings load a moment after this singleton starts (see services/Blur.qml
  // for the same wait): nothing is sent before they have settled.
  property bool settled: false

  Timer {
    interval: 200
    running: true
    onTriggered: {
      root.settled = true
      if (root.active) root.apply()
      else root.readGaps()
    }
  }

  onActiveChanged: {
    if (!root.settled) return
    if (root.active) {
      root.apply()
    } else {
      reload.running = true
    }
  }

  // A slider changes them at every step of a drag: they are sent once it
  // pauses for a moment.
  onOptionsChanged: if (root.settled && root.active) applyTimer.restart()

  Timer {
    id: applyTimer
    interval: 100
    onTriggered: root.apply()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name !== "configreloaded" || !root.settled) return
      if (root.active) root.apply()
      else root.readGaps()
    }
  }

  function apply() {
    root.gapsOut = [Settings.windowGapsOut, Settings.windowGapsOut, Settings.windowGapsOut, Settings.windowGapsOut]
    process.command = ["hyprctl", "eval", `hl.config(${root.options})`]
    process.running = true
  }

  // Reads Hyprland's own gaps_out (the config's, when not synced).
  function readGaps() {
    gapsProbe.running = true
  }

  Process {
    id: process
  }

  // Puts the Hyprland config's own values back when the sync is turned off.
  Process {
    id: reload
    command: ["hyprctl", "reload"]
  }

  Process {
    id: gapsProbe
    command: ["hyprctl", "getoption", "general:gaps_out", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const values = JSON.parse(text).css.trim().split(/\s+/).map(Number)
          if (values.every(value => !isNaN(value))) {
            // CSS order: one value for all sides, or top/bottom and
            // left/right, or top, left/right and bottom, or all four.
            const [t, r = t, b = t, l = r] = values
            root.gapsOut = [t, r, b, l]
          }
        } catch (e) {}
      }
    }
  }
}
