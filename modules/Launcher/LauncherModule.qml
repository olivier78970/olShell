import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The launcher (LauncherPanel.qml), built only while it is open and freed once
// it closes, so a panel that isn't showing takes no memory. Its `launcher` IPC
// target lives here, so it answers while the panel isn't built.
Scope {
  IpcHandler {
    target: "launcher"
    enabled: Settings.widgetEnabled("launcher")

    function toggle(): void {
      LauncherState.toggle()
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: LauncherState.visible
  }

  LazyLoader {
    active: linger.active && Settings.widgetEnabled("launcher")

    LauncherPanel {}
  }
}
