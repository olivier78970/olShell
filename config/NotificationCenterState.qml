pragma Singleton

import Quickshell

// Shared visibility for the notification center, so the bar's bell and the
// IPC handler toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

  function toggle() {
    // All these panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    root.visible = !root.visible
  }
}
