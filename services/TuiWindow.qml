import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// A TUI application (see scripts/tui-launch.py) in a floating, centered
// terminal window that opens and closes like a panel: toggle() opens it, or
// closes it if it's already open (`options` of toggle() can ask for something
// other than the usual window: see open()). The window is themed with the shell's
// current colors and as translucent as its widgets (so Hyprland can blur what's
// behind it). Needs Hyprland, which is asked to float, size and center
// the window when it launches it (no config of yours is involved).
Scope {
  id: root

  // The application to start: "btop" or "wiremix".
  required property string app
  // The terminal command, without the `-e APP` part. Its window class is how
  // the window is found again to close it.
  required property var terminal
  required property string windowClass
  // The window's size, as fractions of the focused monitor.
  property real widthFraction: 0.85
  property real heightFraction: 0.9

  // Kept as a property (rather than read on demand) so Hyprland's monitor
  // data is already loaded by the time the window is opened.
  readonly property var monitor: Hyprland.focusedMonitor

  // What the next open() should do differently, from toggle()'s `options`.
  property var pending: ({})

  function toggle(options) {
    root.pending = options ?? {}
    probe.running = true
  }

  // A Lua string literal for `text`.
  function lua(text) {
    return JSON.stringify(text)
  }

  // `options` (all optional): `boxes`, the btop boxes to show instead of the
  // ones in its configuration ("net", "cpu mem"...); `widthFraction` and
  // `heightFraction`, a size other than the usual one.
  function open() {
    const options = root.pending
    const widthFraction = options.widthFraction ?? root.widthFraction
    const heightFraction = options.heightFraction ?? root.heightFraction
    // Window sizes are in logical pixels, monitor sizes in physical ones.
    const scale = root.monitor ? root.monitor.scale : 1
    const width = root.monitor ? Math.round(root.monitor.width / scale * widthFraction) : 1200
    const height = root.monitor ? Math.round(root.monitor.height / scale * heightFraction) : 800

    // The launcher themes the application (and the terminal) with the colors
    // the shell is using right now.
    const quote = arg => "'" + String(arg).replace(/'/g, "'\\''") + "'"
    const command = ["python3", Quickshell.shellPath("scripts/tui-launch.py"),
      "--app", root.app,
      "--background", Theme.backgroundColor.toString(),
      "--surface", Theme.pillColor.toString(),
      "--text", Theme.textColor.toString(),
      "--accent", Theme.accentColor.toString(),
      "--outline", Theme.outlineColor.toString(),
      "--warning", Theme.warningColor.toString(),
      "--opacity", Theme.widgetOpacity.toFixed(2)]
      .concat(options.boxes ? ["--boxes", options.boxes] : [])
      .concat(["--"]).concat(root.terminal).map(quote).join(" ")
    Hyprland.dispatch("hl.dsp.exec_cmd(" + root.lua(command) + ", { float = true, center = true, size = "
      + root.lua(width + " " + height) + " })")
  }

  function close() {
    Hyprland.dispatch("hl.dsp.window.close({ window = " + root.lua("class:" + root.windowClass) + " })")
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
          isOpen = JSON.parse(text).some(client => client.class === root.windowClass)
        } catch (e) {
          // Unreadable answer: assume it's closed and open a new one.
        }
        if (isOpen) root.close()
        else root.open()
      }
    }
  }
}
