pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// btop in a floating, centered terminal window that opens and closes like a
// panel: toggle() opens it, or closes it if it's already open. The terminal
// and size are in config/Apps.qml. The window is themed with the shell's
// current colors (scripts/btop-launch.py). Needs Hyprland, which is asked to
// float, size and center the window when it launches it (no config of yours
// is involved).
//
//   quickshell -p . ipc call btop toggle
Singleton {
  id: root

  // Kept as a property (rather than read on demand) so Hyprland's monitor
  // data is already loaded by the time the window is opened.
  readonly property var monitor: Hyprland.focusedMonitor

  function toggle() {
    probe.running = true
  }

  // A Lua string literal for `text`.
  function lua(text) {
    return JSON.stringify(text)
  }

  function open() {
    // Window sizes are in logical pixels, monitor sizes in physical ones.
    const scale = root.monitor ? root.monitor.scale : 1
    const width = root.monitor ? Math.round(root.monitor.width / scale * Apps.btopWidth) : 1200
    const height = root.monitor ? Math.round(root.monitor.height / scale * Apps.btopHeight) : 800

    // The launcher themes btop (and the terminal) with the colors the shell
    // is using right now.
    const quote = arg => "'" + String(arg).replace(/'/g, "'\\''") + "'"
    const command = ["python3", Quickshell.shellPath("scripts/btop-launch.py"),
      "--background", Theme.backgroundColor.toString(),
      "--surface", Theme.pillColor.toString(),
      "--text", Theme.textColor.toString(),
      "--accent", Theme.accentColor.toString(),
      "--outline", Theme.outlineColor.toString(),
      "--"].concat(Apps.btopTerminal).map(quote).join(" ")
    Hyprland.dispatch("hl.dsp.exec_cmd(" + root.lua(command) + ", { float = true, center = true, size = "
      + root.lua(width + " " + height) + " })")
  }

  function close() {
    Hyprland.dispatch("hl.dsp.window.close({ window = " + root.lua("class:" + Apps.btopClass) + " })")
  }

  IpcHandler {
    target: "btop"

    function toggle(): void {
      root.toggle()
    }
  }

  // Is the window open? Asked of Hyprland itself, so it's right even if the
  // window was closed by hand or opened before a shell reload.
  Process {
    id: probe
    command: ["hyprctl", "clients", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        let isOpen = false
        try {
          isOpen = JSON.parse(text).some(client => client.class === Apps.btopClass)
        } catch (e) {
          // Unreadable answer: assume it's closed and open a new one.
        }
        if (isOpen) root.close()
        else root.open()
      }
    }
  }
}
