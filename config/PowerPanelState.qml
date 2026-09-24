pragma Singleton

import Quickshell

// Shared visibility for the power panel, so the bar's power button and the
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
    NotificationCenterState.visible = false
    ClockPanelState.visible = false
    ShortcutsPanelState.visible = false
    NotificationActionsState.visible = false
    root.visible = !root.visible
  }
}
