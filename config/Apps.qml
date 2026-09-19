pragma Singleton

import Quickshell

// The applications opened by clicking bar widgets (btop, wiremix, bluetui).
// Edit here to swap the terminal or the window size.
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
  // The size of a window showing only some of btop's boxes, as the CPU, RAM and
  // network widgets open it: it needs less room.
  readonly property real btopBoxWidth: 0.5
  readonly property real btopBoxHeight: 0.5

  // The wiremix window (see services/Wiremix.qml), opened by clicking the
  // volume widget: same idea as btop, with its own window class and size.
  readonly property string wiremixClass: "quickshell-wiremix"
  readonly property var wiremixTerminal: ["alacritty", "--class", wiremixClass, "-T", "wiremix"]
  readonly property real wiremixWidth: 0.6
  readonly property real wiremixHeight: 0.7

  // The bluetui window (see services/Bluetui.qml), opened by left-clicking the
  // Bluetooth tray icon.
  readonly property string bluetuiClass: "quickshell-bluetui"
  readonly property var bluetuiTerminal: ["alacritty", "--class", bluetuiClass, "-T", "bluetui"]
  readonly property real bluetuiWidth: 0.5
  readonly property real bluetuiHeight: 0.6

  // What a left click does on some tray icons, by tray item id, instead of
  // the application's own action: "bluetui" opens/closes the bluetui window.
  // (An item's id is the application's name, e.g. "blueman" for Blueman.)
  readonly property var trayLeftClick: ({
    "blueman": "bluetui"
  })
}
