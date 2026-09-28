pragma Singleton

import Quickshell

// Shared state of the app switcher, so its IPC handler and the panel (only
// built while open) agree on whether it's open and which window is selected.
Singleton {
  id: root

  property bool visible: false
  // Whether it was opened by stepping (`next` / `prev`, as a Super+Tab
  // binding does): releasing the modifier held then switches to the selected
  // window, as `confirm` does.
  property bool cycling: false
  // The selected window, counted in the list from the most recently focused
  // (0, the current one); any number, taken modulo the list's length, so -1
  // is the last one.
  property int current: 1
  // Asked of the panel by `confirm`: switch to the selected window.
  signal confirmRequested()

  // Closes every other panel, since they all grab the keyboard.
  function closeOthers() {
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    ClockPanelState.visible = false
    ShortcutsPanelState.visible = false
    NotificationActionsState.visible = false
  }

  // Opens it on the previously focused window, or closes it.
  function toggle() {
    root.closeOthers()
    root.cycling = false
    root.current = 1
    root.visible = !root.visible
  }

  // Moves the selection `delta` windows on (negative: back); opens it first,
  // on the previously focused window (or the last one, going back), when
  // it's closed.
  function step(delta) {
    if (root.visible) {
      root.current += delta
      return
    }
    root.closeOthers()
    root.cycling = true
    root.current = delta > 0 ? 1 : -1
    root.visible = true
  }

  // Switches to the selected window, if it's open.
  function confirm() {
    if (root.visible) root.confirmRequested()
  }
}
