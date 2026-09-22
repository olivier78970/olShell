pragma Singleton

import Quickshell

// Shared visibility for the application launcher, so both the bar's trigger
// widget and the IPC handler can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

  function toggle() {
    // All these panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    root.visible = !root.visible
  }
}
