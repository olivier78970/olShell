import Quickshell
import qs.modules.Bar
import qs.services

ShellRoot {
  // Singletons are created on first use; this one has to exist from the
  // start to answer its IPC calls and track the focused monitor.
  readonly property var btopMonitor: Btop.monitor
  // Same for the lock-key watcher: it has to run before the first toggle.
  readonly property var lockKeys: LockKeys.ready

  Bar {}
  PowerConfirmDialog {}
  VolumeOsd {}
  LockKeysOsd {}
  WallpaperPanel {}
  ThemePanel {}
  LauncherPanel {}
  SettingsPanel {}
}
