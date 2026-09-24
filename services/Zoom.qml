pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Screen zoom, through Hyprland's own cursor:zoom_factor (the whole screen
// magnified around the pointer, by the compositor itself), up to
// Settings.zoomMax. Driven from outside, e.g. from Hyprland keybinds:
//   quickshell -p . ipc call zoom zoomIn        (by Settings.zoomStep)
//   quickshell -p . ipc call zoom zoomOut
//   quickshell -p . ipc call zoom zoomInBy 1    (by a step of its own)
//   quickshell -p . ipc call zoom zoomOutBy 1
//   quickshell -p . ipc call zoom reset
//   quickshell -p . ipc call zoom set 2
// Like services/Blur.qml's rule, the option is set with `hyprctl eval`
// (the Lua config's parser refuses `hyprctl keyword`), and a config reload
// puts it back to the config's own value, so it's reapplied after each one.
Singleton {
  id: root

  readonly property real minimum: 1
  readonly property real maximum: Settings.zoomMax
  // How much one wheel notch, or one zoomIn/zoomOut, changes the factor.
  readonly property real step: Settings.zoomStep
  // The current zoom factor (1 = none).
  property real factor: 1
  readonly property bool zoomed: root.factor > 1
  // Where the pointer was at the last read (readCursor()), in global
  // coordinates: the zoom is centered on it, so it tells what part of the
  // screen is seen (see modules/Osd/ZoomOsd.qml). Asked of Hyprland, since
  // the pointer is usually over some app's window, where the shell can't
  // see it.
  property point cursor: Qt.point(0, 0)
  // Whether the next read of `cursor` follows a change of the factor.
  property bool changePending: false

  // The factor changed and `cursor` has been read for it.
  signal updated()

  function set(value) {
    const clamped = Math.max(root.minimum, Math.min(root.maximum, Math.round(value * 100) / 100))
    if (clamped === root.factor) return
    root.factor = clamped
    root.apply()
    root.changePending = true
    root.readCursor()
  }

  function zoomIn(step) {
    root.set(root.factor + (step ?? root.step))
  }

  function zoomOut(step) {
    root.set(root.factor - (step ?? root.step))
  }

  // A lower maximum set while zoomed further in zooms back out to it.
  onMaximumChanged: if (root.factor > root.maximum) root.set(root.maximum)

  function reset() {
    root.set(1)
  }

  // A change asked for while hyprctl is still running (scrolling to zoom
  // sends them faster than it returns): sent once it's done, with the
  // factor as it is by then, instead of being lost.
  property bool pending: false

  function apply() {
    if (process.running) {
      root.pending = true
      return
    }
    process.command = ["hyprctl", "eval", `hl.config({ cursor = { zoom_factor = ${root.factor} } })`]
    process.running = true
  }

  // Starts from the factor Hyprland actually has (the shell may be
  // restarted, or reload its config, while zoomed), without re-sending it.
  Process {
    running: true
    command: ["hyprctl", "getoption", "-j", "cursor:zoom_factor"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const value = JSON.parse(this.text).float
          if (value >= root.minimum && value <= root.maximum) root.factor = Math.round(value * 100) / 100
          // Zoomed further in than the maximum allows: back to it.
          else if (value > root.maximum) root.set(root.maximum)
        } catch (e) {}
      }
    }
  }

  // Reads `cursor` again (the OSD follows the pointer while it's shown). A
  // read already running gives the current position anyway, so another one
  // isn't needed.
  function readCursor() {
    if (!cursorProcess.running) cursorProcess.running = true
  }

  Process {
    id: cursorProcess
    command: ["hyprctl", "cursorpos", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const pos = JSON.parse(this.text)
          root.cursor = Qt.point(pos.x, pos.y)
        } catch (e) {}
        if (!root.changePending) return
        root.changePending = false
        root.updated()
      }
    }
  }

  Process {
    id: process

    onExited: {
      if (!root.pending) return
      root.pending = false
      root.apply()
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded" && root.zoomed) root.apply()
    }
  }

  IpcHandler {
    target: "zoom"

    function zoomIn(): void {
      root.zoomIn()
    }

    function zoomOut(): void {
      root.zoomOut()
    }

    function zoomInBy(step: real): void {
      if (step > 0) root.zoomIn(step)
    }

    function zoomOutBy(step: real): void {
      if (step > 0) root.zoomOut(step)
    }

    function reset(): void {
      root.reset()
    }

    function set(value: real): void {
      root.set(value)
    }

    function get(): real {
      return root.factor
    }
  }
}
