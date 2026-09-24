pragma Singleton

import Quickshell

// Shared visibility for the keyboard shortcuts panel, so its IPC handler and
// anything else can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

  function toggle() {
    // Panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    root.visible = !root.visible
  }
}
