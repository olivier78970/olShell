import QtQuick
import Quickshell.Services.SystemTray
import qs.components
import qs.config

// Row of system tray icons (a column on a side bar), one per registered tray
// application, except the ones in Apps.hiddenTrayItems.
BarStack {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  gap: 15
  stackGap: 12

  Repeater {
    model: SystemTray.items.values.filter(item => !Apps.hiddenTrayItems.includes(item.id))
    TrayItem {}
  }
}
