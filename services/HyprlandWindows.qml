pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Sets Hyprland's window look from the shell's settings: the windows' border
// width and corner radius (their own, or the shell's border width and widget
// radius), the gaps between windows (their own, or the shell's gap between
// elements) and around them, and the opacity of the focused window and of the
// others. They are set live with `hl.config()`, replacing the Hyprland
// config's values, and set again after every config reload (which puts the
// config's back).
//
// It also gives Hyprland's gaps_out, which the bar needs (see Bar.qml's
// exclusiveZone).
Singleton {
  id: root

  // The values sent to Hyprland.
  readonly property int borderSize: Settings.windowBorderSame ? Settings.borderWidth : Settings.windowBorderWidth
  readonly property int rounding: Settings.windowRoundingSame ? Settings.radius : Settings.windowRounding
  readonly property int gapsIn: Settings.windowGapsInSame ? Settings.panelGap : Settings.windowGapsIn

  // Hyprland's gaps_out as top, right, bottom, left.
  readonly property var gapsOut: [Settings.windowGapsOut, Settings.windowGapsOut, Settings.windowGapsOut, Settings.windowGapsOut]

  // As the Lua table hl.config() takes.
  readonly property string options: `{ general = { border_size = ${root.borderSize}, gaps_in = ${root.gapsIn}, gaps_out = ${Settings.windowGapsOut} }, decoration = { rounding = ${root.rounding}, active_opacity = ${Settings.windowActiveOpacity}, inactive_opacity = ${Settings.windowInactiveOpacity} } }`

  // Settings load a moment after this singleton starts (see services/Blur.qml
  // for the same wait): nothing is sent before they have settled.
  property bool settled: false

  Timer {
    interval: 200
    running: true
    onTriggered: {
      root.settled = true
      root.apply()
    }
  }

  // A slider changes them at every step of a drag: they are sent once it
  // pauses for a moment.
  onOptionsChanged: if (root.settled) applyTimer.restart()

  Timer {
    id: applyTimer
    interval: 100
    onTriggered: root.apply()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name !== "configreloaded" || !root.settled) return
      root.apply()
    }
  }

  function apply() {
    process.command = ["hyprctl", "eval", `hl.config(${root.options})`]
    process.running = true
  }

  Process {
    id: process
  }
}
