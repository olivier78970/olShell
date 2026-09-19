pragma Singleton

import Quickshell

// The applications opened by clicking bar widgets (btop, wiremix). Edit here
// to swap the terminal or the window size.
Singleton {
  // The btop window (see services/Btop.qml): a terminal, without the
  // `-e btop` part which is added by scripts/tui-launch.py, started with a
  // dedicated window class so the shell can find it again to close it.
  // Colors are applied automatically for alacritty; another terminal opens
  // with its own colors (btop itself is themed either way).
  readonly property string btopClass: "quickshell-btop"
  readonly property var btopTerminal: ["alacritty", "--class", btopClass, "-T", "btop"]
  // Its size, as fractions of the focused monitor.
  readonly property real btopWidth: 0.85
  readonly property real btopHeight: 0.9

  // The wiremix window (see services/Wiremix.qml), opened by clicking the
  // volume widget: same idea as btop, with its own window class and size.
  readonly property string wiremixClass: "quickshell-wiremix"
  readonly property var wiremixTerminal: ["alacritty", "--class", wiremixClass, "-T", "wiremix"]
  readonly property real wiremixWidth: 0.6
  readonly property real wiremixHeight: 0.7
}
