pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Gives GTK and Qt apps the shell's font family (Settings.fontFamily) and
// their own size (Settings.appFontSize) while Settings.appFontSync is on,
// through scripts/app-fonts.py: gsettings for GTK, the [Fonts] section of
// the qt5ct and qt6ct settings for Qt. Their monospace font is
// Settings.monoFontFamily.
// Alacritty always gets the monospace family and its own size
// (Settings.alacrittyFontSize) in ~/.config/alacritty/font.toml, and in the
// alacritty windows already open.
// It is applied at startup and again once the settings have stopped
// changing. Turning the GTK and Qt sync off gives those apps their default
// font back (the font keys are removed, so it doesn't clobber a font set
// elsewhere at startup).
Singleton {
  id: root

  // The fonts the apps should have, which changes whenever one of them does
  // (and gives shell.qml a property to reference).
  readonly property string wanted: [
    Settings.fontFamily,
    Settings.monoFontFamily,
    Settings.appFontSync ? Settings.appFontSize : "",
    Settings.alacrittyFontSize
  ].join("|")

  // Set when the GTK and Qt sync was just turned off, until the default
  // fonts have been restored.
  property bool restoreApps: false

  onWantedChanged: settled.restart()

  Connections {
    target: Settings
    function onAppFontSyncChanged() {
      root.restoreApps = !Settings.appFontSync
      settled.restart()
    }
  }
  Component.onCompleted: settled.restart()

  // Waits for a slider or a font choice to stop changing.
  Timer {
    id: settled
    interval: 800
    onTriggered: {
      apply.running = false
      const command = ["python3", Paths.appFontsScript, Settings.fontFamily, Settings.monoFontFamily]
      if (Settings.appFontSync) command.push("--apps", String(Settings.appFontSize))
      else if (root.restoreApps) command.push("--restore-apps")
      root.restoreApps = false
      command.push("--alacritty", String(Settings.alacrittyFontSize))
      apply.command = command
      apply.running = true
    }
  }

  Process {
    id: apply
  }
}
