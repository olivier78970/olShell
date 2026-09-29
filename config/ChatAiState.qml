pragma Singleton

import Quickshell

// Shared visibility for the chat AI panel, so its IPC handler and the bar's
// button toggle the same panel instance. The question and answer themselves
// are kept by services/ChatAi.qml, so they outlive the panel.
Singleton {
  id: root

  property bool visible: false
  // The id of the provider picked in the panel, "" for the first one that
  // can be asked (see services/ChatAi.qml); kept between openings.
  property string provider: ""
  // The model picked in the panel for each provider, by provider id, in
  // place of its default (the one set in the settings) until the shell
  // restarts; a provider without one asks its default.
  property var models: ({})

  function toggle() {
    // Panels grab the keyboard, so only one may be open at a time.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    ShortcutsPanelState.visible = false
    NotificationActionsState.visible = false
    AppSwitcherState.visible = false
    root.visible = !root.visible
  }
}
