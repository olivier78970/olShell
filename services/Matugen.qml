pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Runs matugen (matugen/quickshell.toml), which regenerates the color files
// the shell and other apps (Zen...) read, from the palette of the selected
// theme: the wallpaper's for "Automatique", the accent color's for a fixed or
// custom theme (it has no image, only colors, so matugen builds a palette
// around its accent). It uses a dedicated config so this doesn't also restart
// unrelated apps (waybar, wofi...) that the shared
// ~/.config/matugen/config.toml themes.
//
// A run also rewrites GeneratedColors.json, which "Automatique" reads, so
// while another theme is selected it holds that theme's palette, not the
// wallpaper's; selecting "Automatique" regenerates it.
//
// "Automatique" is built with the mode, scheme style, source color, contrast
// and lightness chosen in the settings (Settings.themeMode, matugenScheme,
// matugenSource, matugenContrast and matugenLightness). A fixed or custom
// theme's apps get a palette around its accent in its own mode, and with
// Settings.themeExactApps the templates use the theme's exact colors for its
// main roles instead (background, text, widgets, border, accent; see
// templateData). The accent the shell picks from the "Automatique" palette
// (matugenAccent) and its widget background (themePill) need no run:
// GeneratedColors.json has every candidate.
//
// Changing any of that regenerates the colors once the settings have stopped
// changing for a moment (a slider changes at every step of a drag, and every
// run makes Hyprland reload its config), unless they are back to what the
// colors were made with.
//
// matugen only colors the apps turned on in the settings, and the apps added
// there with templates of their own (see scripts/matugen-run.py), with any
// theme; turning one on, or adding or changing an added one, runs it again
// so the app gets the current colors now.
//
// Each run is remembered by a stamp: for "Automatique" the wallpaper, when
// its file last changed, and the settings it is built with; for another
// theme its mode and colors. Restoring the wallpaper at startup skips
// matugen when the stamp is the same as the last run's: the colors would be
// the same, and rewriting ~/.config/hypr/colors.lua makes Hyprland reload
// its config for nothing (which undoes what was set with `hyprctl eval`,
// such as the dynamic rules and QS_CONFIG_PATH).
Singleton {
  id: root

  // Called after the wallpaper was applied and remembered in ThemeState.
  // `onlyIfChanged` skips the run when nothing changed since the last one
  // (the restore at startup).
  function applyWallpaper(path, onlyIfChanged) {
    ThemeState.setWallpaper(path)
    // Another theme ignores the wallpaper: it is only remembered, for when
    // "Automatique" is selected again.
    if (ThemeState.active.kind === "auto")
      request(onlyIfChanged === true)
  }

  // Called after ThemeState.select().
  function applyTheme() {
    request(false)
  }

  // The apps matugen colors, as scripts/matugen-run.py takes them.
  readonly property var apps: [
    Settings.matugenHyprland ? "hyprland" : "",
    Settings.matugenZen ? "zen" : "",
    Settings.matugenAlacritty ? "alacritty" : "",
    Settings.matugenGtk ? "gtk" : "",
    Settings.matugenQt ? "qt" : "",
    Settings.matugenStarship ? "starship" : ""
  ].filter(app => app !== "")

  // The added apps that are on and have their files set, as JSON for
  // scripts/matugen-run.py.
  readonly property string addedApps: JSON.stringify(Settings.matugenApps
    .filter(app => app.on && app.template.length > 0 && app.output.length > 0)
    .map(app => ({ name: app.name, template: app.template, output: app.output, hook: app.hook })))

  // The added apps as they were, to tell whether a change added or changed
  // one (which needs a run) or only removed or turned one off (which doesn't).
  property var lastAddedApps: JSON.parse(root.addedApps)

  onAddedAppsChanged: {
    const before = root.lastAddedApps.map(app => JSON.stringify(app))
    const now = JSON.parse(root.addedApps)
    root.lastAddedApps = now
    if (now.some(app => !before.includes(JSON.stringify(app))))
      appsSettled.restart()
  }

  // Everything the colors are made from besides the wallpaper, so a change
  // to any of it regenerates them (once it has settled, see below).
  readonly property string wantedColors: JSON.stringify([
    ThemeState.active.id,
    ThemeState.active.mode,
    ThemeState.active.colors ?? null,
    Settings.matugenScheme,
    Settings.matugenSource,
    Settings.matugenContrast,
    Settings.matugenLightness,
    Settings.themeExactApps
  ])

  onWantedColorsChanged: settled.restart()

  // Regenerates the colors once what they are made from has stopped
  // changing, unless it is back to what the colors were made with.
  Timer {
    id: settled
    interval: 1000
    onTriggered: root.request(true)
  }

  // Waits for the apps to stop changing when one was turned on (one turned
  // off just keeps its colors).
  Connections {
    target: Settings

    function onMatugenHyprlandChanged() {
      if (Settings.matugenHyprland) appsSettled.restart()
    }

    function onMatugenZenChanged() {
      if (Settings.matugenZen) appsSettled.restart()
    }

    function onMatugenAlacrittyChanged() {
      if (Settings.matugenAlacritty) appsSettled.restart()
    }

    function onMatugenGtkChanged() {
      if (Settings.matugenGtk) appsSettled.restart()
    }

    function onMatugenQtChanged() {
      if (Settings.matugenQt) appsSettled.restart()
    }

    function onMatugenStarshipChanged() {
      if (Settings.matugenStarship) appsSettled.restart()
    }
  }

  // Colors the apps turned on once they have stopped changing, with any
  // theme (the stamp doesn't hold the apps, so this isn't skipped).
  Timer {
    id: appsSettled
    interval: 1000
    onTriggered: root.request(false)
  }

  // The background lightness option for matugen: Settings.matugenLightness
  // (-1 to 1) scaled to what stays usable in the mode. Past about -0.1 in dark
  // and +0.05 in light the background and the pills both turn pure black or
  // white, and past +0.2 in dark or -0.2 in light the background gets as
  // light or as dark as the text's opposite.
  function lightnessOption(mode) {
    const value = Settings.matugenLightness
    if (mode === "light")
      return "--lightness-light=" + (value < 0 ? value * 0.2 : value * 0.05)
    return "--lightness-dark=" + (value < 0 ? value * 0.1 : value * 0.2)
  }

  // `color` tinted toward `target` by `amount` (0-1), as "#rrggbb".
  function mix(color, target, amount) {
    const to = Qt.color(target)
    return Qt.tint(Qt.color(color), Qt.rgba(to.r, to.g, to.b, amount)).toString()
  }

  // The data the templates get besides matugen's colors (see
  // matugen/quickshell.toml): the GTK theme the olShell one is built on, and
  // `exact`, whether they use the theme colors given here for their main
  // roles instead of matugen's. `colors` are a fixed or custom theme's five
  // colors, or null for none; the other roles the templates need are made
  // from them (the secondary text, and the widget background a step lower
  // and higher).
  function templateData(mode, colors) {
    const data = { gtkTheme: mode === "light" ? "adw-gtk3" : "adw-gtk3-dark", exact: colors !== null }
    if (colors !== null) {
      Object.assign(data, {
        background: colors.backgroundColor,
        text: colors.textColor,
        textVariant: root.mix(colors.textColor, colors.backgroundColor, 0.3),
        pill: colors.pillColor,
        pillLow: root.mix(colors.pillColor, colors.backgroundColor, 0.5),
        pillHigh: root.mix(colors.pillColor, colors.textColor, 0.08),
        border: colors.borderColor,
        accent: colors.accentColor,
        onAccent: colors.backgroundColor
      })
      // Hyprland's colors are written without the #.
      data.backgroundStripped = data.background.slice(1)
      data.textStripped = data.text.slice(1)
    }
    return ["--import-json-string", JSON.stringify({ olshell: data })]
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
    if (theme.kind !== "auto") {
      const exact = Settings.themeExactApps ? theme.colors : null
      const stamp = "theme|" + JSON.stringify([theme.id, theme.mode, theme.colors, exact !== null])
      const command = ["python3", Paths.matugenScript, Paths.matugenConfig, root.apps.join(","), root.addedApps, "color", "hex", theme.colors.accentColor, "-m", theme.mode]
      root.launch(command.concat(root.templateData(theme.mode, exact)), stamp, wantedIfChanged)
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
      const mode = Settings.themeMode
      const scheme = Settings.matugenScheme
      const source = Settings.matugenSource
      const contrast = String(Settings.matugenContrast)
      const lightness = root.lightnessOption(mode)
      const stamp = code === 0 ? ["auto", probe.path, probeOutput.text.trim(), mode, scheme, source, contrast, lightness].join("|") : ""
      // "dominant" is the first of the image's colors, which always exists
      // (a higher index fails on an image with fewer colors).
      const pick = source === "dominant" ? ["--source-color-index", "0"] : ["--prefer", source]
      const command = ["python3", Paths.matugenScript, Paths.matugenConfig, root.apps.join(","), root.addedApps, "image", probe.path, "-m", mode, "-t", "scheme-" + scheme, "--contrast", contrast, lightness]
      root.launch(command.concat(pick, root.templateData(mode, null)), stamp, probe.onlyIfChanged && stamp !== "")
    }
  }
}
