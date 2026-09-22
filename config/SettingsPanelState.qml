pragma Singleton

import Quickshell

// Shared visibility for the settings panel, so the IPC handler (and any
// future bar button) can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

  function toggle() {
    // All these panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    root.visible = !root.visible
  }
}
