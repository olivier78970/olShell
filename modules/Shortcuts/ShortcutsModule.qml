import Quickshell
import Quickshell.Io
import qs.config

// The shortcuts panel (ShortcutsPanel.qml), built only while it is open and
// freed once it closes, so a panel that isn't showing takes no memory. Its
// `shortcuts` IPC target lives here, so it answers while the panel isn't
// built.
Scope {
  IpcHandler {
    target: "shortcuts"

    function toggle(): void {
      ShortcutsPanelState.toggle()
    }
  }

  LazyLoader {
    active: ShortcutsPanelState.visible

    ShortcutsPanel {}
  }
}
