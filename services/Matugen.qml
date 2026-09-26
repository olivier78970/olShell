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
//
// Each run is remembered by a stamp: the theme, and for "Automatique" the
// wallpaper and when its file last changed. Restoring the wallpaper at
// startup skips matugen when the stamp is the same as the last run's: the
// colors would be the same, and rewriting ~/.config/hypr/colors.lua makes
// Hyprland reload its config for nothing (which undoes what was set with
// `hyprctl eval`, such as the dynamic rules and QS_CONFIG_PATH).
Singleton {
  id: root

  // Called after the wallpaper was applied and remembered in ThemeState.
  // `onlyIfChanged` skips the run when nothing changed since the last one
  // (the restore at startup).
  function applyWallpaper(path, onlyIfChanged) {
    ThemeState.setWallpaper(path)
    // A fixed theme ignores the wallpaper: it is only remembered, for when
    // "Automatique" is selected again.
    if (ThemeState.active.colors === undefined)
      request(onlyIfChanged === true)
  }

  // Called after ThemeState.select().
  function applyTheme() {
    request(false)
  }

  property bool wanted: false
  // Whether what is wanted may be skipped when nothing changed; a request
  // that may not be wins over one that may.
  property bool wantedIfChanged: false

  function request(onlyIfChanged) {
    wantedIfChanged = (wanted ? wantedIfChanged : true) && onlyIfChanged
    wanted = true
    start.restart()
  }

  // Runs what was asked for, one matugen at a time: a request arriving while
  // one runs is picked up when it exits.
  function next() {
    if (run.running || probe.running || !wanted)
      return
    wanted = false

    const theme = ThemeState.active
    if (theme.colors) {
      root.launch(["matugen", "color", "hex", theme.colors.accentColor, "-m", "dark", "-c", Paths.matugenConfig], theme.id, wantedIfChanged)
    } else if (ThemeState.wallpaper.length > 0) {
      // The stamp needs when the wallpaper's file last changed: read it first.
      probe.path = ThemeState.wallpaper
      probe.onlyIfChanged = wantedIfChanged
      probe.command = ["stat", "-c", "%Y", "--", probe.path]
      probe.running = true
    }
  }

  // Runs matugen with `command`, unless `onlyIfChanged` and `stamp` is the
  // last run's.
  function launch(command, stamp, onlyIfChanged) {
    if (onlyIfChanged && stamp === ThemeState.generated) {
      root.next()
      return
    }
    run.stamp = stamp
    run.command = command
    run.running = true
  }

  // Starting matugen in the same tick as the wallpaper command reliably makes
  // one of the two Process spawns silently no-op, so a request waits a moment
  // first.
  Timer {
    id: start
    interval: 300
    onTriggered: root.next()
  }

  // No stdout collector: matugen's hooks for other apps spawn long-lived
  // background processes that would keep an attached pipe open indefinitely.
  Process {
    id: run

    property string stamp: ""

    onExited: code => {
      ThemeState.setGenerated(code === 0 ? run.stamp : "")
      root.next()
    }
  }

  // Reads when the wallpaper's file last changed, for its stamp.
  Process {
    id: probe

    property string path: ""
    property bool onlyIfChanged: false

    stdout: StdioCollector {
      id: probeOutput
    }

    onExited: code => {
      const stamp = code === 0 ? "auto|" + probe.path + "|" + probeOutput.text.trim() : ""
      root.launch(["matugen", "image", probe.path, "-m", "dark", "--prefer", "saturation", "-c", Paths.matugenConfig], stamp, probe.onlyIfChanged && stamp !== "")
    }
  }
}
