pragma Singleton

import QtQuick
import Quickshell
import qs.modules.Bar.Widgets

// The widgets the bar can hold, by id (the ids are Settings.widgetIds; where
// each one goes is Settings.layout). WidgetSlot loads a widget from here.
Singleton {
  id: root

  readonly property var components: ({
    launcher: launcher,
    settings: settings,
    workspaces: workspaces,
    activeWindow: activeWindow,
    clock: clock,
    wallpaper: wallpaper,
    theme: theme,
    screenshot: screenshot,
    zoom: zoom,
    shortcuts: shortcuts,
    tray: tray,
    cpu: cpu,
    ram: ram,
    disk: disk,
    network: network,
    connection: connection,
    bluetooth: bluetooth,
    volume: volume,
    notifications: notifications,
    lock: lock,
    power: power
  })

  Component { id: launcher; LauncherTrigger {} }
  Component { id: settings; SettingsTrigger {} }
  Component { id: workspaces; Workspaces {} }
  Component { id: activeWindow; ActiveWindow {} }
  Component { id: clock; Clock {} }
  Component { id: wallpaper; WallpaperTrigger {} }
  Component { id: theme; ThemeTrigger {} }
  Component { id: screenshot; ScreenshotButton {} }
  Component { id: zoom; ZoomButton {} }
  Component { id: shortcuts; ShortcutsTrigger {} }
  Component { id: tray; Tray {} }
  Component { id: cpu; CpuUsage {} }
  Component { id: ram; RamUsage {} }
  Component { id: disk; DiskUsage {} }
  Component { id: network; NetworkSpeed {} }
  Component { id: connection; ConnectionButton {} }
  Component { id: bluetooth; BluetoothButton {} }
  Component { id: volume; Volume {} }
  Component { id: notifications; NotificationBell {} }
  Component { id: lock; LockButton {} }
  Component { id: power; PowerTrigger {} }
}
