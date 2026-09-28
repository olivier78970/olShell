import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The notification actions panel (NotificationActionsPanel.qml), built only
// while it is open and freed once it closes, so a panel that isn't showing
// takes no memory. Its `notificationActions` IPC target lives here, so it
// answers while the panel isn't built.
Scope {
  IpcHandler {
    target: "notificationActions"

    function toggle(): void {
      NotificationActionsState.toggle()
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: NotificationActionsState.visible
  }

  LazyLoader {
    active: linger.active

    NotificationActionsPanel {}
  }
}
