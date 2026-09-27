pragma Singleton

import Quickshell

// Shared visibility for the settings panel, so the IPC handler (and any
// future bar button) can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false
  // Set while the panel is hidden only for a moment (to pick a color from the
  // screen): it stays built then (see modules/Settings/SettingsModule.qml),
  // and opens back where it was instead of on its first row.
  property bool resuming: false
  // The category and tab last shown. The panel is built anew each time it
  // opens, so it keeps them here to open on them again.
  property int category: 0
  property int tab: 0

  function toggle() {
    // All these panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    ShortcutsPanelState.visible = false
    NotificationActionsState.visible = false
    root.visible = !root.visible
  }
}
