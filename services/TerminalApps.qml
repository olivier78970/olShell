pragma Singleton

import Quickshell
import Quickshell.Hyprland
import qs.config

// Runs a terminal application (yazi, btop, gdu...) in Apps.appTerminal, in a
// floating window centered on the focused monitor, or any program in such a
// window. The launcher uses it for the desktop entries that ask for a
// terminal, and the bar widgets for their click action (see
// WidgetActions.qml).
Singleton {
  id: root

  // Kept as a property (rather than read on demand) so Hyprland's monitor
  // data is already loaded by the time a window is opened.
  readonly property var monitor: Hyprland.focusedMonitor

  // `command` (a program and its arguments) run by the terminal, with window
  // class `windowClass` when there is one (so the window can be found again).
  // The class goes before Apps.appTerminal's last word, the option that takes
  // the command.
  function terminalCommand(command, windowClass) {
    const terminal = windowClass
      ? Apps.appTerminal.slice(0, -1).concat(["--class", windowClass, Apps.appTerminal[Apps.appTerminal.length - 1]])
      : Apps.appTerminal
    return terminal.concat(command)
  }

  // Opens `command` in a floating window centered on the focused monitor
  // (Apps.appTerminalWidth by Apps.appTerminalHeight of it), after changing to
  // `workingDirectory` when there is one: Hyprland gives the window the first
  // one the program opens. It starts it as a shell command, so each argument
  // is quoted.
  function launchFloating(command, workingDirectory) {
    // Window sizes are in logical pixels, monitor sizes in physical ones.
    const scale = root.monitor ? root.monitor.scale : 1
    const width = root.monitor ? Math.round(root.monitor.width / scale * Apps.appTerminalWidth) : 1200
    const height = root.monitor ? Math.round(root.monitor.height / scale * Apps.appTerminalHeight) : 800
    const quote = arg => "'" + String(arg).replace(/'/g, "'\\''") + "'"
    let line = command.map(quote).join(" ")
    if (workingDirectory) line = "cd " + quote(workingDirectory) + " && " + line
    Hyprland.dispatch("hl.dsp.exec_cmd(" + JSON.stringify(line) + ", { float = true, center = true, size = "
      + JSON.stringify(width + " " + height) + " })")
  }

  // Opens `command` in the terminal, in a floating window (see
  // launchFloating()), with window class `windowClass` when there is one.
  function launch(command, workingDirectory, windowClass) {
    root.launchFloating(root.terminalCommand(command, windowClass), workingDirectory)
  }
}
