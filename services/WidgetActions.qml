pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// What a click on a configurable bar widget does. Each of the CPU, RAM,
// storage, network speed, network and Bluetooth widgets has a command in the
// settings (`<id>Action`, empty to do nothing), whether it runs in a terminal
// (`<id>ActionTerminal`) and whether its window opens floating in the middle
// of the screen (`<id>ActionFloating`). If the application it started is still
// open, a click switches to its window instead of starting another one: a
// terminal one has a window class of its own (`quickshell-<id>`), the others
// are found by the program's name being their window class (blueman-manager
// has the class "blueman-manager"); an application whose class differs is
// simply started again. A floating one opens like a terminal application of
// the launcher (see TerminalApps.qml), a tiled one is started as it is.
// The command's words are run without a shell.
Singleton {
  id: root

  // The widgets with such an action, by id.
  readonly property var ids: ["cpu", "ram", "disk", "network", "connection", "bluetooth"]

  // The action being run: { words, terminal, floating, windowClass }, once the open
  // windows are known.
  property var pending: null

  // Runs widget `id`'s action, if it has one.
  function run(id) {
    const words = WebApps.split(Settings.get(id + "Action"))
    if (words.length === 0) return
    const terminal = Settings.get(id + "ActionTerminal")
    root.pending = {
      words: words,
      terminal: terminal,
      floating: Settings.get(id + "ActionFloating"),
      windowClass: terminal ? "quickshell-" + id : words[0].split("/").pop()
    }
    probe.running = true
  }

  // Switches to the window of the pending action when it is open, else starts it.
  function start(clients) {
    const action = root.pending
    const wanted = action.windowClass.toLowerCase()
    const open = clients.find(client => client.class.toLowerCase() === wanted)
    if (open) Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:" + open.address) + " })")
    else if (action.floating) TerminalApps.launchFloating(action.terminal ? TerminalApps.terminalCommand(action.words, action.windowClass) : action.words)
    else Quickshell.execDetached(action.terminal ? TerminalApps.terminalCommand(action.words, action.windowClass) : action.words)
  }

  // The open windows, asked of Hyprland itself so it's right even after a
  // shell reload.
  Process {
    id: probe
    command: ["hyprctl", "clients", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        let clients = []
        try {
          clients = JSON.parse(text)
        } catch (e) {
          // Unreadable answer: start the application.
        }
        root.start(clients)
      }
    }
  }
}
