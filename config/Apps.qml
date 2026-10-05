pragma Singleton

import Quickshell

// The applications the shell opens in a terminal (nmcli, and the launcher's
// and the bar widgets' terminal applications).
// (The volume widget opens pavucontrol, a window of its own.)
// Edit here to swap the terminal or the window size.
Singleton {
  // The terminal the connection widget opens to ask for a Wi-Fi password, or
  // a hidden network's name (see services/NetworkManager.qml), without the
  // `-e ...` part.
  readonly property var networkTerminal: ["alacritty", "--class", "quickshell-network", "-T", "nmcli"]

  // Tray items the bar's tray leaves out, by their id: blueman's applet,
  // which the Bluetooth widget stands in for (it starts whenever a blueman
  // window opens).
  readonly property var hiddenTrayItems: ["blueman"]

  // Applications in the Game category that aren't games but launchers and
  // tools for them, by desktop entry id: the launcher's Games tab leaves them
  // out (they stay in its Applications tab).
  readonly property var notGames: ["steam", "com.heroicgameslauncher.hgl", "io.github.Faugus.faugus-launcher", "io.github.benjamimgois.goverlay"]

  // The terminal the launcher runs a terminal application in (a desktop
  // entry with Terminal=true, such as yazi or htop), and the bar widgets a
  // click action that runs in a terminal, followed by its command,
  // and the size of its floating, centered window, as fractions of the
  // focused monitor.
  readonly property var appTerminal: ["alacritty", "-e"]
  readonly property real appTerminalWidth: 0.6
  readonly property real appTerminalHeight: 0.7

  // The options of `awww img` used when a wallpaper is applied (see
  // scripts/apply-wallpaper.py; `awww img --help` lists them): how the image
  // fills the screen, and the transition's smoothness. The transition's type
  // and duration are settings (see config/Settings.qml), added after these.
  // Picks a color from the screen for the settings' color picker (see
  // components/ColorPicker.qml): it prints the color clicked as "#rrggbb",
  // and nothing when cancelled with Escape. Not --quiet, which may silence
  // the color too.
  readonly property var screenColorPicker: ["hyprpicker", "--format=hex", "--lowercase-hex", "--no-fancy"]

  readonly property var wallpaperOptions: ["--resize", "crop", "--transition-step", "63", "--transition-fps", "60"]

  // The engine the launcher's web search uses for the default browser's
  // entry when that browser's own can't be read (see services/WebSearch.qml;
  // %s is where the search goes).
  readonly property var webSearchFallback: ({ name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" })
  // The icons of the search engines, by the start of their name in lower
  // case; any other has a magnifier.
  readonly property var webSearchIcons: ({ duckduckgo: "󰇥", google: "󰊭", bing: "󰂤", wikip: "󰖬", youtube: "󰗃" })
}
