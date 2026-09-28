pragma Singleton

import Quickshell
import Quickshell.Io

// Shared state of the app switcher, so its IPC handler and the panel (only
// built while open) agree on whether it's open and which window is selected.
Singleton {
  id: root

  property bool visible: false
  // Whether it was opened by its shortcut or by stepping (`next` / `prev`):
  // releasing the shortcut's modifier then switches to the selected window,
  // as `confirm` does, and the shortcut pressed again moves on.
  property bool cycling: false
  // The keys of the Hyprland config's shortcut running `switcher toggle`
  // (such as ["Super", "Tab"]), read from the config each time it opens
  // (scripts/list-shortcuts.py); [] while unknown.
  property var shortcut: []
  // Its modifiers ("Super", "Alt", "Ctrl", "Shift", "AltGr") and its key.
  readonly property var modifiers: root.shortcut.filter(key => root.modifierNames.includes(key))
  readonly property string key: root.shortcut.find(key => !root.modifierNames.includes(key)) ?? ""
  readonly property var modifierNames: ["Super", "Alt", "Ctrl", "Shift", "AltGr"]
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

  // Opens it on the previously focused window. While it's open, moves on
  // to the next window instead, as the shortcut pressed again with its
  // modifier still held does; it only closes when the shortcut has no
  // modifier to release.
  function toggle() {
    if (root.visible && root.cycling) {
      root.current += 1
      return
    }
    if (root.visible) {
      root.visible = false
      return
    }
    root.closeOthers()
    root.cycling = root.shortcut.length === 0 || root.modifiers.length > 0
    root.current = 1
    root.visible = true
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

  // Reads the shortcut again each time it opens, so a config just edited
  // counts (the last one read stands meanwhile).
  onVisibleChanged: if (root.visible) reader.running = true

  Process {
    id: reader
    command: ["python3", Paths.listShortcutsScript, "--all"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const found = JSON.parse(this.text).shortcuts.find(shortcut => shortcut.action === "shell" && shortcut.arg === "switcher.toggle")
          root.shortcut = found ? found.keys : []
        } catch (e) {
          root.shortcut = []
        }
      }
    }
  }
}
