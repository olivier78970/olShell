import Quickshell
import Quickshell.Io
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

  LazyLoader {
    active: ThemePanelState.visible

    ThemePanel {}
  }
}
