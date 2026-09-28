import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The theme panel (ThemePanel.qml), built only while it is open and freed once
// it closes, so a panel that isn't showing takes no memory. Its `themes` IPC
// target lives here, so it answers while the panel isn't built.
Scope {
  IpcHandler {
    target: "themes"

    function themesToggle(): void {
      ThemePanelState.toggle()
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: ThemePanelState.visible
  }

  LazyLoader {
    active: linger.active

    ThemePanel {}
  }
}
