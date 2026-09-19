pragma Singleton

import Quickshell

// Shared visibility for the theme panel, so both the bar's trigger widget
// and the IPC handler can toggle the same panel instance.
Singleton {
  id: root

  property bool visible: false

  function toggle() {
    // Both panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    root.visible = !root.visible
  }
}
