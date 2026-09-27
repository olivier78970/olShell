import QtQuick
import Quickshell.Services.SystemTray
import qs.config

// Row of system tray icons, one per registered tray application, except the
// ones in Apps.hiddenTrayItems.
Row {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  spacing: 15

  Repeater {
    model: SystemTray.items.values.filter(item => !Apps.hiddenTrayItems.includes(item.id))
    TrayItem {}
  }
}
