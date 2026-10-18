pragma Singleton

import Quickshell
import Quickshell.Io

// The currently selected theme, remembered across restarts in
// ThemeState.json. `active` is that theme as it is used right now (see
// ThemePresets.resolve: its colors follow the theme settings). Each
// monitor's wallpaper is kept there too, by monitor name, to restore them at
// startup and so "Automatique" can be regenerated from the main monitor's
// when it is selected again (see services/Matugen.qml). A
// wallpaper is a file path, or "pod" for the Bing picture of the day, which
// stands for the newest picture of the Bing folder (see BingWallpaper.resolve).
Singleton {
  id: root

  readonly property var active: ThemePresets.resolve(file.adapter.selected)
  readonly property var wallpapers: file.adapter.wallpapers ?? ({})
  // What matugen last made the colors from (see services/Matugen.qml's
  // stamps), so a run that would make the same colors can be skipped.
  readonly property string generated: file.adapter.generated

  function select(id) {
    file.adapter.selected = id
    file.writeAdapter()
  }

  // The wallpaper of the monitor `name`: its own, or the main monitor's for a
  // monitor that has none (one connected since); empty when there is none.
  function wallpaperOf(name) {
    return root.wallpapers[name] ?? root.wallpapers[Settings.activeMainMonitor] ?? ""
  }

  // Remembers `path` as `monitor`'s wallpaper.
  function setWallpaper(path, monitor) {
    file.adapter.wallpapers = Object.assign({}, root.wallpapers, { [monitor]: path })
    file.writeAdapter()
  }

  // Replaces the remembered wallpapers (what applying a profile does).
  function setWallpapers(perMonitor) {
    file.adapter.wallpapers = perMonitor
    file.writeAdapter()
  }

  function setGenerated(stamp) {
    file.adapter.generated = stamp
    file.writeAdapter()
  }

  FileView {
    id: file
    path: Paths.themeState
    // Read synchronously so the saved theme is in place from the first
    // frame instead of flashing "auto" and then fading to it.
    blockLoading: true

    JsonAdapter {
      property string selected: "auto"
      property var wallpapers: ({})
      property string generated: ""
    }
  }
}
