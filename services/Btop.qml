pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// btop in a floating, centered terminal window that opens and closes like a
// panel: toggle() opens it, or closes it if it's already open (see
// TuiWindow.qml). The terminal and size are in config/Apps.qml.
//
//   quickshell -p . ipc call btop toggle
Singleton {
  id: root

  readonly property var monitor: window.monitor

  function toggle() {
    window.toggle()
  }

  TuiWindow {
    id: window
    app: "btop"
    terminal: Apps.btopTerminal
    windowClass: Apps.btopClass
    widthFraction: Apps.btopWidth
    heightFraction: Apps.btopHeight
  }

  IpcHandler {
    target: "btop"

    function toggle(): void {
      root.toggle()
    }
  }
}
