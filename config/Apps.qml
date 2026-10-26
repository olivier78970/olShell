pragma Singleton

import Quickshell

// The terminals the shell can open applications in (nmcli, and the
// launcher's and the bar widgets' terminal applications).
// (The volume widget opens pavucontrol, a window of its own.)
// The terminal itself is a setting (Settings.defaultTerminal); edit here to
// add a terminal or change the window size.
Singleton {
  id: root

  // The terminals the shell knows how to run a program in, by desktop entry
  // id: the program, and the arguments giving its window a class, giving it
  // a title and coming before the program it runs. The settings' terminal
  // (Settings.defaultTerminal) is one of them, and only these are offered.
  readonly property var terminals: ({
    "Alacritty.desktop": { command: ["alacritty"], classArgs: name => ["--class", name], titleArgs: title => ["-T", title], runArgs: ["-e"] },
    "kitty.desktop": { command: ["kitty"], classArgs: name => ["--class", name], titleArgs: title => ["-T", title], runArgs: [] },
    "foot.desktop": { command: ["foot"], classArgs: name => ["--app-id=" + name], titleArgs: title => ["--title=" + title], runArgs: [] },
    "com.mitchellh.ghostty.desktop": { command: ["ghostty"], classArgs: name => ["--class=" + name], titleArgs: title => ["--title=" + title], runArgs: ["-e"] },
    "org.wezfurlong.wezterm.desktop": { command: ["wezterm", "start"], classArgs: name => ["--class", name], titleArgs: title => [], runArgs: ["--"] }
  })
  // The terminal in use: the settings' one, or Alacritty when the shell
  // doesn't know it.
  readonly property var terminal: root.terminals[Settings.defaultTerminal] ?? root.terminals["Alacritty.desktop"]

  // The command running `command` (a program and its arguments) in the
  // terminal, with window class `windowClass` and title `title` when given.
  function terminalCommand(command, windowClass, title) {
    return root.terminal.command
      .concat(windowClass ? root.terminal.classArgs(windowClass) : [])
      .concat(title ? root.terminal.titleArgs(title) : [])
      .concat(root.terminal.runArgs, command)
  }

  // Tray items the bar's tray leaves out, by their id: blueman's applet,
  // which the Bluetooth widget stands in for (it starts whenever a blueman
  // window opens).
  readonly property var hiddenTrayItems: ["blueman"]

  // Applications in the Game category that aren't games but launchers and
  // tools for them, by desktop entry id: the launcher's Games tab leaves them
  // out (they stay in its Applications tab).
  readonly property var notGames: ["steam", "com.heroicgameslauncher.hgl", "io.github.Faugus.faugus-launcher", "io.github.benjamimgois.goverlay"]

  // The size of the floating, centered window of a terminal application
  // the launcher runs (a desktop entry with Terminal=true, such as yazi or
  // htop), or of a bar widget's click action run in a terminal, as fractions
  // of the focused monitor.
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

  // The address composing a mail from a mailto: link, by the web mail's
  // site (its address's host): a web app on one of these sites can be the
  // default mail client (see services/DefaultApps.qml). %s is where the
  // link goes, encoded.
  readonly property var webMailCompose: ({
    "mail.google.com": "https://mail.google.com/mail/?extsrc=mailto&url=%s",
    "gmail.com": "https://mail.google.com/mail/?extsrc=mailto&url=%s",
    "outlook.live.com": "https://outlook.live.com/mail/0/deeplink/compose?mailtouri=%s",
    "outlook.office.com": "https://outlook.office.com/mail/deeplink/compose?mailtouri=%s"
  })
}
