import Quickshell
import Quickshell.Io
import qs.config

// The launcher (LauncherPanel.qml), built only while it is open and freed once
// it closes, so a panel that isn't showing takes no memory. Its `launcher` IPC
// target lives here, so it answers while the panel isn't built.
Scope {
  IpcHandler {
    target: "launcher"

    function toggle(): void {
      LauncherState.toggle()
    }
  }

  LazyLoader {
    active: LauncherState.visible

    LauncherPanel {}
  }
}
