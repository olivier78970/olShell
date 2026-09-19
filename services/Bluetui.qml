pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// bluetui, a TUI Bluetooth manager, in a floating, centered terminal window
// that opens and closes like a panel: toggle() opens it, or closes it if it's
// already open (see TuiWindow.qml). The terminal and size are in
// config/Apps.qml.
//
//   quickshell -p . ipc call bluetui toggle
Singleton {
  id: root

  readonly property var monitor: window.monitor

  function toggle() {
    window.toggle()
  }

  TuiWindow {
    id: window
    app: "bluetui"
    terminal: Apps.bluetuiTerminal
    windowClass: Apps.bluetuiClass
    widthFraction: Apps.bluetuiWidth
    heightFraction: Apps.bluetuiHeight
  }

  IpcHandler {
    target: "bluetui"

    function toggle(): void {
      root.toggle()
    }
  }
}
