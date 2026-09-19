pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// btop in a floating, centered terminal window that opens and closes like a
// panel: toggle() opens it, or closes it if it's already open (see
// TuiWindow.qml). The terminal and size are in config/Apps.qml. toggle("net")
// opens it with only the network box ("cpu", "mem", or any boxes: "cpu mem"),
// in a smaller window; that's what the bar's CPU, RAM and network widgets do.
//
//   quickshell -p . ipc call btop toggle
//   quickshell -p . ipc call btop cpu      (also memory, network)
Singleton {
  id: root

  readonly property var monitor: window.monitor

  // btop settings to change when only these boxes are shown: the memory box
  // comes with the disks, which the RAM widget doesn't want.
  readonly property var boxSettings: ({ "mem": { "show_disks": "False" } })

  function toggle(boxes) {
    window.toggle(boxes ? {
      boxes: boxes,
      settings: root.boxSettings[boxes] ?? {},
      widthFraction: Apps.btopBoxWidth,
      heightFraction: Apps.btopBoxHeight
    } : {})
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

    function cpu(): void {
      root.toggle("cpu")
    }

    function memory(): void {
      root.toggle("mem")
    }

    function network(): void {
      root.toggle("net")
    }
  }
}
