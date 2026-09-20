pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Runs matugen, which regenerates the color files the shell and other apps
// (Zen...) read. Two configs, so a theme never overwrites the wallpaper's
// palette that "Automatique" shows (see the matugen/ directory):
//  - quickshell.toml: the shell's palette, from the wallpaper.
//  - apps.toml: the other apps, from the palette of the selected theme: the
//    wallpaper's for "Automatique", the accent color's for a fixed theme
//    (a fixed theme has no image, only colors).
// Both are kept apart from the shared ~/.config/matugen/config.toml so this
// doesn't also restart unrelated apps (waybar, wofi...) that it themes.
Singleton {
  id: root

  // Called after the wallpaper was applied and remembered in ThemeState.
  function applyWallpaper(path) {
    ThemeState.setWallpaper(path)
    paletteWanted = true
    // A fixed theme ignores the wallpaper.
    appsWanted = ThemeState.active.colors === undefined
    start.restart()
  }

  // Called after ThemeState.select().
  function applyTheme() {
    appsWanted = true
    start.restart()
  }

  property bool paletteWanted: false
  property bool appsWanted: false

  // Runs what was asked for, one matugen at a time: a request arriving while
  // one runs is picked up when it exits (see the Process handlers below).
  function next() {
    if (palette.running || apps.running)
      return

    if (paletteWanted) {
      paletteWanted = false
      if (ThemeState.wallpaper.length > 0) {
        palette.command = imageCommand(Paths.matugenConfig)
        palette.running = true
        return
      }
    }

    if (appsWanted) {
      appsWanted = false
      const theme = ThemeState.active
      if (theme.colors) {
        apps.command = ["matugen", "color", "hex", theme.colors.accentColor, "-m", "dark", "-c", Paths.matugenAppsConfig]
        apps.running = true
      } else if (ThemeState.wallpaper.length > 0) {
        apps.command = imageCommand(Paths.matugenAppsConfig)
        apps.running = true
      }
    }
  }

  function imageCommand(config) {
    return ["matugen", "image", ThemeState.wallpaper, "-m", "dark", "--prefer", "saturation", "-c", config]
  }

  // Starting matugen in the same tick as waypaper reliably makes one of the
  // two Process spawns silently no-op, so a request waits a moment first.
  Timer {
    id: start
    interval: 300
    onTriggered: root.next()
  }

  // No stdout collectors: matugen's hooks for other apps spawn long-lived
  // background processes that would keep an attached pipe open indefinitely.
  Process {
    id: palette
    onExited: root.next()
  }

  Process {
    id: apps
    onExited: root.next()
  }
}
