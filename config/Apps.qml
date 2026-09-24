pragma Singleton

import Quickshell

// The applications the shell opens in a terminal (btop, gdu).
// (The volume widget opens pavucontrol, a window of its own.)
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

  // The gdu window (see services/Gdu.qml), opened by clicking the disk widget:
  // a disk usage analyzer for the disk mounted on /.
  readonly property string gduClass: "quickshell-gdu"
  readonly property var gduTerminal: ["alacritty", "--class", gduClass, "-T", "gdu"]
  readonly property real gduWidth: 0.6
  readonly property real gduHeight: 0.7

  // The options of `awww img` used when a wallpaper is applied (see
  // scripts/apply-wallpaper.py; `awww img --help` lists them): how the image
  // fills the screen, and the transition's smoothness. The transition's type
  // and duration are settings (see config/Settings.qml), added after these.
  readonly property var wallpaperOptions: ["--resize", "crop", "--transition-step", "63", "--transition-fps", "60"]
}
