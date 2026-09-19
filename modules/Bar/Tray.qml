import QtQuick
import Quickshell.Services.SystemTray

// Row of system tray icons, one per registered tray application.
Row {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  spacing: 15

  Repeater {
    model: SystemTray.items
    TrayItem {}
  }
}
