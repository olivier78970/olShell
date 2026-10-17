import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// On each screen, its monitor's name and resolution in a large pill at the
// center, while MonitorLayout.identifying is on (the settings' Identify
// button), to tell the monitors apart. The surfaces cover their screens with
// an empty input region, so clicks pass through.
Variants {
  model: Quickshell.screens

  PanelWindow {
    id: window

    required property var modelData
    readonly property var monitor: MonitorLayout.monitorOf(window.modelData.name)

    screen: window.modelData
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    aboveWindows: true
    focusable: false
    mask: Region {}

    Rectangle {
      anchors.centerIn: parent
      width: label.implicitWidth + 80
      height: label.implicitHeight + 60
      radius: Theme.radiusFor(height)
      color: Theme.fade(Theme.pillColor, 0.95)
      border.color: Theme.accentColor
      border.width: 3

      Column {
        id: label
        anchors.centerIn: parent
        spacing: 6

        ThemedText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰍹  " + window.modelData.name
          sizeScale: 3
          color: Theme.accentColor
        }

        ThemedText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: window.monitor?.description ?? ""
          sizeScale: 1.1
        }

        ThemedText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: window.monitor ? window.monitor.resolution : ""
          sizeScale: 1.1
          color: Theme.separatorColor
        }
      }
    }
  }
}
