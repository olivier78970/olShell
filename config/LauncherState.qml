pragma Singleton

import Quickshell
import Quickshell.Io

// Shared visibility for the application launcher, so both the bar's trigger
// widget and the IPC handler can toggle the same panel instance. It also
// remembers the applications last opened from it, across restarts, in
// LauncherState.json: the launcher lists them first (as many as
// Settings.launcherHistory) and selects the latest.
Singleton {
  id: root

  property bool visible: false
  // The desktop entry ids of the applications (and games) last opened from
  // the launcher, the latest first, at most `maxRecent`.
  readonly property var recentApps: file.adapter.recentApps
  // How many are kept: the most the history setting allows.
  readonly property int maxRecent: Settings.limits.launcherHistory[1]

  function toggle() {
    // All these panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    ShortcutsPanelState.visible = false
    AppSwitcherState.visible = false
    NotificationActionsState.visible = false
    root.visible = !root.visible
  }

  // Puts an application first in the history (moving it up if it was there).
  function addRecent(id) {
    const recent = file.adapter.recentApps
    if (recent[0] === id) return
    file.adapter.recentApps = [id].concat(recent.filter(other => other !== id)).slice(0, root.maxRecent)
    file.writeAdapter()
  }

  FileView {
    id: file
    path: Paths.launcherState
    // Read synchronously: the launcher can open right after the shell starts.
    blockLoading: true
    // The file only exists once an application has been opened.
    printErrors: false

    JsonAdapter {
      property var recentApps: []
    }
  }
}
