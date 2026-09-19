pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// gdu, a disk usage analyzer, on the disk mounted on /, in a floating,
// centered terminal window that opens and closes like a panel: toggle() opens
// it, or closes it if it's already open (see TuiWindow.qml). The terminal and
// size are in config/Apps.qml.
//
//   quickshell -p . ipc call gdu toggle
Singleton {
  id: root

  readonly property var monitor: window.monitor

  function toggle() {
    window.toggle()
  }

  TuiWindow {
    id: window
    app: "gdu"
    terminal: Apps.gduTerminal
    windowClass: Apps.gduClass
    widthFraction: Apps.gduWidth
    heightFraction: Apps.gduHeight
  }

  IpcHandler {
    target: "gdu"

    function toggle(): void {
      root.toggle()
    }
  }
}
