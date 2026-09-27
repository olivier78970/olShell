import Quickshell
import Quickshell.Io
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

  LazyLoader {
    active: NotificationActionsState.visible

    NotificationActionsPanel {}
  }
}
