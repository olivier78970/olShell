pragma Singleton

import Quickshell

// Shared visibility for the wallpaper panel, so both the bar's trigger
// widget and the IPC handler (used by the SUPER + CTRL + W keybind) can
// toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

  function toggle() {
    // Both panels grab the keyboard, so only one may be open at a time.
    ThemePanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    root.visible = !root.visible
  }
}
