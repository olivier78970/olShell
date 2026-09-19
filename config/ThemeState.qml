pragma Singleton

import Quickshell
import Quickshell.Io

// The currently selected theme, remembered across restarts in
// ThemeState.json. `active` is the matching entry of ThemePresets.
Singleton {
  id: root

  readonly property var active: ThemePresets.byId(file.adapter.selected)

  function select(id) {
    file.adapter.selected = id
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
    }
  }
}
