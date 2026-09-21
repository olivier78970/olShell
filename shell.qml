import Quickshell
import qs.components
import qs.modules.Bar
import qs.modules.Launcher
import qs.modules.Osd
import qs.modules.Settings
import qs.modules.Theme
import qs.modules.Wallpapers
import qs.services

ShellRoot {
  // Singletons are created on first use; this one has to exist from the
  // start to answer its IPC calls and track the focused monitor.
  readonly property var btopMonitor: Btop.monitor
  readonly property var wiremixMonitor: Wiremix.monitor
  readonly property var bluetuiMonitor: Bluetui.monitor
  readonly property var gduMonitor: Gdu.monitor
  // Same for the lock-key watcher: it has to run before the first toggle.
  readonly property var lockKeys: LockKeys.ready
  // And the screenshot service, which answers the `screenshot` IPC calls.
  readonly property var screenshotMode: Screenshot.mode

  Bar {}
  PowerConfirmDialog {}
  VolumeOsd {}
  LockKeysOsd {}
  WallpaperPanel {}
  ThemePanel {}
  LauncherPanel {}
  SettingsPanel {}
}
