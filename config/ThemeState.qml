pragma Singleton

import Quickshell
import Quickshell.Io

// The currently selected theme, remembered across restarts in
// ThemeState.json. `active` is the matching entry of ThemePresets. The last
// applied wallpaper is kept there too, so "Automatique" can be regenerated
// from it when it is selected again (see services/Matugen.qml).
Singleton {
  id: root

  readonly property var active: ThemePresets.byId(file.adapter.selected)
  readonly property string wallpaper: file.adapter.wallpaper
  // What matugen last made the colors from (see services/Matugen.qml's
  // stamps), so a run that would make the same colors can be skipped.
  readonly property string generated: file.adapter.generated

  function select(id) {
    file.adapter.selected = id
    file.writeAdapter()
  }

  function setWallpaper(path) {
    file.adapter.wallpaper = path
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
      property string wallpaper: ""
      property string generated: ""
    }
  }
}
