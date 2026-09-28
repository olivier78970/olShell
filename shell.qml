// Apps' icons are looked up in the Adwaita icon theme (and the themes it
// inherits, AdwaitaLegacy then hicolor): an icon only a theme provides, such
// as nm-connection-editor's, isn't found in hicolor alone.
//@ pragma IconTheme Adwaita
import Quickshell
import qs.components
import qs.modules.AppSwitcher
import qs.modules.Bar
import qs.modules.Clock
import qs.modules.Launcher
import qs.modules.Lock
import qs.modules.Notifications
import qs.modules.Osd
import qs.modules.Polkit
import qs.modules.Power
import qs.modules.Settings
import qs.modules.Shortcuts
import qs.modules.Theme
import qs.modules.Wallpapers
import qs.services

ShellRoot {
  // Singletons are created on first use; this one has to exist from the
  // start to answer its IPC calls and track the focused monitor.
  readonly property var btopMonitor: Btop.monitor
  readonly property var gduMonitor: Gdu.monitor
  // Same for the lock-key watcher: it has to run before the first toggle.
  readonly property var lockKeys: LockKeys.ready
  // And the screenshot service, which answers the `screenshot` IPC calls.
  readonly property var screenshotMode: Screenshot.mode
  // And the notification server, which has to own its D-Bus name from the start.
  readonly property var notificationsDnd: Notifications.dnd
  // And the blur service, which has to apply Settings.blur's saved value
  // from the start (Hyprland forgets dynamic layer rules on its own restart).
  readonly property var blurActive: Blur.active
  // And the zoom service, which answers the `zoom` IPC calls.
  readonly property var zoomFactor: Zoom.factor
  // And the polkit agent, which has to register with polkit from the start.
  readonly property var polkitRegistered: Polkit.registered
  // And the service pointing Hyprland's QS_CONFIG_PATH at this shell.
  readonly property var configPath: ConfigPath.path
  // And the one syncing Hyprland's window look, which has to apply the
  // saved settings from the start.
  readonly property var hyprlandWindows: HyprlandWindows.active

  Bar {}
  ClockPanel {}
  PowerConfirmDialog {}
  VolumeOsd {}
  ZoomOsd {}
  ZoomShield {}
  LockKeysOsd {}
  WallpaperPanel {}
  ThemeModule {}
  LauncherModule {}
  SettingsModule {}
  ShortcutsModule {}
  AppSwitcherModule {}
  NotificationPopups {}
  NotificationCenter {}
  NotificationActionsModule {}
  PowerModule {}
  PolkitDialog {}
  LockScreen {}
}
