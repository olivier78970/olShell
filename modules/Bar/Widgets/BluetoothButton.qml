import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config

// Bluetooth icon, doing what blueman's tray icon does: crossed out while
// Bluetooth is off (or there is no adapter), with a link while a device is
// connected. Hovering it lists the connected devices with their battery; a
// click opens blueman's device manager and a right click a menu to switch
// Bluetooth on or off, make it discoverable, disconnect or reconnect a
// device, send files, and open blueman's other windows.
Item {
  id: root

  // The adapter in use (null without one), and whether it's on.
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool on: root.adapter !== null && root.adapter.enabled
  // The adapter's devices: the connected ones, and the paired ones that
  // aren't, which the menu offers to reconnect.
  readonly property var devices: root.adapter ? root.adapter.devices.values : []
  readonly property var connectedDevices: root.devices.filter(device => device.connected)
  readonly property var reconnectable: root.devices.filter(device => device.paired && !device.connected)

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  ThemedText {
    id: icon
    anchors.centerIn: parent
    text: !root.on ? "󰂲" : (root.connectedDevices.length > 0 ? "󰂱" : "󰂯")
    sizeScale: 1.4
    opacity: root.on ? 1 : 0.5
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) menu.visible = !menu.visible
      else Quickshell.execDetached(["blueman-manager"])
    }
    onEntered: tooltip.hoverEntered()
    onExited: tooltip.hoverExited()
  }

  // Starts one of blueman's windows, or runs a menu entry's action, and
  // closes the menu.
  function run(command) {
    menu.visible = false
    Quickshell.execDetached(command)
  }

  // A device's name, with its battery when it reports one.
  function describe(device) {
    return device.batteryAvailable ? I18n.tr("bluetooth.battery", device.name, Math.round(device.battery * 100)) : device.name
  }

  // A thin line between groups of menu entries, as wide as the menu.
  component MenuSeparator: Item {
    anchors.left: parent?.left
    anchors.right: parent?.right
    height: 11

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      height: 1
      radius: 0.5
      color: Theme.separatorColor
      opacity: 0.5
    }
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    PowerMenuOption {
      enabled: root.adapter !== null
      icon: root.on ? "󰂲" : "󰂯"
      label: I18n.tr(root.on ? "bluetooth.turnOff" : "bluetooth.turnOn")
      onClicked: {
        menu.visible = false
        root.adapter.enabled = !root.adapter.enabled
      }
    }

    PowerMenuOption {
      enabled: root.on
      label: I18n.tr(root.adapter?.discoverable ? "bluetooth.hide" : "bluetooth.discoverable")
      onClicked: {
        menu.visible = false
        root.adapter.discoverable = !root.adapter.discoverable
      }
    }

    MenuSeparator {
      visible: root.connectedDevices.length > 0
    }

    Repeater {
      model: root.connectedDevices

      PowerMenuOption {
        required property var modelData
        label: I18n.tr("bluetooth.disconnect", modelData.name)
        onClicked: {
          menu.visible = false
          modelData.disconnect()
        }
      }
    }

    MenuSeparator {}

    PowerMenuOption {
      enabled: root.on
      label: I18n.tr("bluetooth.sendFiles")
      onClicked: root.run(["blueman-sendto"])
    }

    MenuSeparator {
      visible: root.reconnectable.length > 0
    }

    // The paired devices that aren't connected, under a heading: a click
    // connects one.
    PowerMenuOption {
      visible: root.reconnectable.length > 0
      enabled: false
      label: I18n.tr("bluetooth.reconnect")
    }

    Repeater {
      model: root.reconnectable

      PowerMenuOption {
        required property var modelData
        enabled: root.on
        label: modelData.name
        onClicked: {
          menu.visible = false
          modelData.connect()
        }
      }
    }

    MenuSeparator {}

    PowerMenuOption {
      label: I18n.tr("bluetooth.devices")
      onClicked: root.run(["blueman-manager"])
    }

    PowerMenuOption {
      label: I18n.tr("bluetooth.adapters")
      onClicked: root.run(["blueman-adapters"])
    }

    PowerMenuOption {
      label: I18n.tr("bluetooth.services")
      onClicked: root.run(["blueman-services"])
    }

    // blueman's plugin settings, which its applet opens (over D-Bus).
    PowerMenuOption {
      label: I18n.tr("bluetooth.plugins")
      onClicked: root.run(["busctl", "--user", "call", "org.blueman.Applet", "/org/blueman/Applet", "org.blueman.Applet", "OpenPluginDialog"])
    }
  }

  // Whether Bluetooth is on, and the connected devices with their battery.
  HoverPopup {
    id: tooltip
    anchorItem: root
    alignCenter: true
    showWhen: !menu.visible

    ThemedText {
      text: root.adapter === null ? I18n.tr("bluetooth.none") : I18n.tr(root.on ? "bluetooth.on" : "bluetooth.off")
    }

    ThemedText {
      visible: root.on
      text: root.connectedDevices.length > 0 ? root.connectedDevices.map(device => root.describe(device)).join("\n") : I18n.tr("bluetooth.noDevice")
      sizeScale: 0.85
    }
  }
}
