pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// wiremix, a TUI audio mixer for PipeWire, in a floating, centered terminal
// window that opens and closes like a panel: toggle() opens it, or closes it
// if it's already open (see TuiWindow.qml). The terminal and size are in
// config/Apps.qml.
//
//   quickshell -p . ipc call wiremix toggle
Singleton {
  id: root

  readonly property var monitor: window.monitor

  function toggle() {
    window.toggle()
  }

  TuiWindow {
    id: window
    app: "wiremix"
    terminal: Apps.wiremixTerminal
    windowClass: Apps.wiremixClass
    widthFraction: Apps.wiremixWidth
    heightFraction: Apps.wiremixHeight
  }

  IpcHandler {
    target: "wiremix"

    function toggle(): void {
      root.toggle()
    }
  }
}
