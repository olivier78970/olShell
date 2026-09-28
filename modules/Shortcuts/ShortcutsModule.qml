import Quickshell
import Quickshell.Io
import qs.components
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

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: ShortcutsPanelState.visible
  }

  LazyLoader {
    active: linger.active

    ShortcutsPanel {}
  }
}
