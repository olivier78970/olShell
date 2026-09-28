pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Sets Hyprland's animations from the shell's settings, on top of the
// Hyprland config's own: whether they run at all, a multiplier on the
// duration of every animation the config sets (or the shell's animation
// duration for all of them), and the style of the windows' and the
// workspaces' animations (or the config's). They are set live with
// `hl.config()` and `hl.animation()`, and set again after every config reload
// (which puts the config's back).
//
// The config's values are the base the settings apply to: read from
// `hyprctl animations -j` right after Hyprland loads its config, before the
// shell changes them. They are also kept in Hyprland's own Lua state
// (olshell_animation_base), which a config reload clears: a shell started
// again while Hyprland keeps its changes reads them back from there, rather
// than taking values it already changed for the config's.
Singleton {
  id: root

  // To keep it running (see shell.qml).
  readonly property bool active: true

  // The animations the config sets, by name: { enabled, speed, curve, style },
  // `curve` as Hyprland gives it (a bezier's name, or "spring:" and a
  // spring's). Empty until read.
  property var base: ({})

  // The leaves whose style follows each style setting.
  readonly property var windowLeaves: ["windows", "windowsIn", "windowsOut"]
  readonly property var workspaceLeaves: ["workspaces", "workspacesIn", "workspacesOut"]

  // As the Lua the settings call for: whether animations run, then every
  // animation the config sets, its duration multiplied (what Hyprland calls
  // its speed is a duration, in tenths of a second), or the shell's animation
  // duration, and its style replaced where a style setting says so.
  readonly property string commands: {
    const lines = [`hl.config({ animations = { enabled = ${Settings.hyprlandAnimations} } })`]
    for (const name in root.base) {
      const leaf = root.base[name]
      const style = root.windowLeaves.includes(name) && Settings.hyprlandWindowStyle !== "config" ? Settings.hyprlandWindowStyle
        : root.workspaceLeaves.includes(name) && Settings.hyprlandWorkspaceStyle !== "config" ? Settings.hyprlandWorkspaceStyle
        : leaf.style
      const curve = leaf.curve.startsWith("spring:") ? `spring = "${leaf.curve.slice(7)}"` : `bezier = "${leaf.curve}"`
      const speed = Settings.hyprlandAnimationSame ? Settings.animationDuration / 100
        : Math.round(leaf.speed * Settings.hyprlandAnimationDuration * 1000) / 1000
      lines.push(`hl.animation({ leaf = "${name}", enabled = ${leaf.enabled}, speed = ${speed}, ${curve}${style ? `, style = "${style}"` : ""} })`)
    }
    return lines.join("\n")
  }

  // Settings load a moment after this singleton starts (see services/Blur.qml
  // for the same wait): nothing is read or sent before they have settled.
  property bool settled: false

  Timer {
    interval: 200
    running: true
    onTriggered: {
      root.settled = true
      root.readBase(true)
    }
  }

  // A slider changes them at every step of a drag: they are sent once it
  // pauses for a moment.
  onCommandsChanged: if (root.settled && Object.keys(root.base).length > 0) applyTimer.restart()

  Timer {
    id: applyTimer
    interval: 100
    onTriggered: root.apply()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded" && root.settled) root.readBase(false)
    }
  }

  // Finds the config's values: kept in Hyprland's Lua state if the shell has
  // already changed them (only asked when `kept` may be there: not right
  // after a config reload, which clears it), read from Hyprland otherwise.
  function readBase(kept) {
    if (kept) keptProcess.running = true
    else animationsProcess.running = true
  }

  // Asks Hyprland for the kept values: an error carrying them (a Lua error is
  // the one way `hyprctl eval` gives something back), or none.
  Process {
    id: keptProcess
    command: ["hyprctl", "eval", "if olshell_animation_base then error('OLSHELL' .. olshell_animation_base, 0) end"]
    stdout: StdioCollector {
      onStreamFinished: {
        const at = text.indexOf("OLSHELL")
        if (at < 0) {
          animationsProcess.running = true
          return
        }
        try {
          root.base = JSON.parse(text.slice(at + 7).trim())
          applyTimer.restart()
        } catch (error) {
          animationsProcess.running = true
        }
      }
    }
  }

  // Reads the animations the config sets from Hyprland (the others inherit
  // theirs), keeps them in Hyprland's Lua state, and applies the settings.
  Process {
    id: animationsProcess
    command: ["hyprctl", "animations", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const found = {}
          for (const leaf of JSON.parse(text)[0]) {
            if (!leaf.overridden || leaf.name.startsWith("__")) continue
            found[leaf.name] = { enabled: leaf.enabled, speed: leaf.speed, curve: leaf.bezier || "default", style: leaf.style }
          }
          root.base = found
          // Even with the same values as before: a config reload has just put
          // the config's back.
          applyTimer.restart()
          keepProcess.command = ["hyprctl", "eval", `olshell_animation_base = [==[${JSON.stringify(found)}]==]`]
          keepProcess.running = true
        } catch (error) {
          root.base = {}
        }
      }
    }
  }

  Process {
    id: keepProcess
  }

  function apply() {
    process.command = ["hyprctl", "eval", root.commands]
    process.running = true
  }

  Process {
    id: process
  }
}
