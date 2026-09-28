import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The power panel (PowerPanel.qml), built only while it is open and freed
// once it closes, so a panel that isn't showing takes no memory. Its `power`
// IPC target lives here, so it answers while the panel isn't built.
Scope {
  // `power toggle` opens or closes the panel; the others do what its buttons
  // do (suspend at once, the rest through the confirmation).
  IpcHandler {
    target: "power"

    function toggle(): void {
      PowerPanelState.toggle()
    }

    function logout(): void {
      PowerPanelState.visible = false
      PowerMenuState.request("logout")
    }

    function restart(): void {
      PowerPanelState.visible = false
      PowerMenuState.request("restart")
    }

    function shutdown(): void {
      PowerPanelState.visible = false
      PowerMenuState.request("shutdown")
    }

    function suspend(): void {
      PowerPanelState.visible = false
      PowerMenuState.suspend()
    }

    function firmware(): void {
      PowerPanelState.visible = false
      PowerMenuState.request("firmware")
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: PowerPanelState.visible
  }

  LazyLoader {
    active: linger.active

    PowerPanel {}
  }
}
