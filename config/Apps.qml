pragma Singleton

import Quickshell

// Commands launched when clicking certain bar widgets. Edit here to swap
// out which application a widget opens.
Singleton {
  readonly property var volumeMixer: ["pavucontrol"]

  // The btop window (see services/Btop.qml): a terminal, without the
  // `-e btop` part which is added by scripts/btop-launch.py, started with a
  // dedicated window class so the shell can find it again to close it.
  // Colors are applied automatically for alacritty; another terminal opens
  // with its own colors (btop itself is themed either way).
  readonly property string btopClass: "quickshell-btop"
  readonly property var btopTerminal: ["alacritty", "--class", btopClass, "-T", "btop"]
  // Its size, as fractions of the focused monitor.
  readonly property real btopWidth: 0.85
  readonly property real btopHeight: 0.9
}
