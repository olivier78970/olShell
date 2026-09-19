import Quickshell
import qs.modules.Bar
import qs.services

ShellRoot {
  // Singletons are created on first use; this one has to exist from the
  // start to answer its IPC calls and track the focused monitor.
  readonly property var btopMonitor: Btop.monitor

  Bar {}
  PowerConfirmDialog {}
  VolumeOsd {}
  WallpaperPanel {}
  ThemePanel {}
  LauncherPanel {}
  SettingsPanel {}
}
