pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Runs matugen (matugen/quickshell.toml), which regenerates the color files
// the shell and other apps (Zen...) read, from the palette of the selected
// theme: the wallpaper's for "Automatique", the accent color's for a fixed
// theme (a fixed theme has no image, only colors, so matugen builds a palette
// around its accent). It uses a dedicated config so this doesn't also restart
// unrelated apps (waybar, wofi...) that the shared ~/.config/matugen/config.toml
// themes.
//
// A run also rewrites GeneratedColors.json, which "Automatique" reads, so while
// a fixed theme is selected it holds that theme's palette, not the wallpaper's;
// selecting "Automatique" regenerates it.
Singleton {
  id: root

  // Called after the wallpaper was applied and remembered in ThemeState.
  function applyWallpaper(path) {
    ThemeState.setWallpaper(path)
    // A fixed theme ignores the wallpaper: it is only remembered, for when
    // "Automatique" is selected again.
    if (ThemeState.active.colors === undefined)
      request()
  }

  // Called after ThemeState.select().
  function applyTheme() {
    request()
  }

  property bool wanted: false

  function request() {
    wanted = true
    start.restart()
  }

  // Runs what was asked for, one matugen at a time: a request arriving while
  // one runs is picked up when it exits.
  function next() {
    if (run.running || !wanted)
      return
    wanted = false

    const theme = ThemeState.active
    if (theme.colors) {
      run.command = ["matugen", "color", "hex", theme.colors.accentColor, "-m", "dark", "-c", Paths.matugenConfig]
      run.running = true
    } else if (ThemeState.wallpaper.length > 0) {
      run.command = ["matugen", "image", ThemeState.wallpaper, "-m", "dark", "--prefer", "saturation", "-c", Paths.matugenConfig]
      run.running = true
    }
  }

  // Starting matugen in the same tick as waypaper reliably makes one of the
  // two Process spawns silently no-op, so a request waits a moment first.
  Timer {
    id: start
    interval: 300
    onTriggered: root.next()
  }

  // No stdout collector: matugen's hooks for other apps spawn long-lived
  // background processes that would keep an attached pipe open indefinitely.
  Process {
    id: run
    onExited: root.next()
  }
}
