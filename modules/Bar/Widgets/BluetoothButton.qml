import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config
import qs.services

// Bluetooth icon, doing what blueman's tray icon does: crossed out while
// Bluetooth is off (or there is no adapter), with a link while a device is
// connected. Hovering it lists the connected devices with their battery; a
// click runs its action (Settings.bluetoothAction) and a right click opens a menu to switch
// Bluetooth on or off, make it discoverable, connect, disconnect or forget a
// paired device, send files, and pair a device found nearby (Add device… scans for them).
Item {
  id: root

  // The adapter in use (null without one), and whether it's on.
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool on: root.adapter !== null && root.adapter.enabled
  // The adapter's devices: the connected ones, and the paired ones, which
  // the menu lists (the connected ones first, then by name).
  readonly property var devices: root.adapter ? root.adapter.devices.values : []
  readonly property var connectedDevices: root.devices.filter(device => device.connected)
  readonly property var pairedDevices: root.devices.filter(device => device.paired)
    .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
  // The devices found nearby that aren't paired, which the menu offers to
  // pair: only the named ones (a scan also turns up a crowd of nameless
  // low-energy beacons), at most maxNearby of them.
  readonly property var nearby: root.devices.filter(device => !device.paired && device.deviceName !== "").slice(0, root.maxNearby)
  readonly property int maxNearby: 8
  // Whether the menu is searching for devices, since its Add device… was
  // clicked (see the Binding below).
  property bool scanning: false
  // The device being paired from the menu, until it's paired (it's then
  // trusted and connected) or the pairing fails.
  property var pairingDevice: null

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.height

  BarText {
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
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else {
        tooltip.dismiss()
        WidgetActions.run("bluetooth")
      }
    }
    onEntered: tooltip.hoverEntered()
    onExited: tooltip.hoverExited()
  }

  // Starts one of blueman's windows, or runs a menu entry's action, and
  // closes the menu.
  function run(command) {
    menu.open = false
    Quickshell.execDetached(command)
  }

  // Pairs a nearby device; finishPairing() connects it once it's paired.
  // blueman's agent asks for a PIN or a confirmation when the device needs
  // one. A pairing still waiting (for a confirmation never given, say) is
  // cancelled first, so a click on another device always does something.
  function pair(device) {
    const pending = root.pairingDevice
    if (pending === device) return
    root.pairingDevice = device
    if (pending !== null && pending.pairing) pending.cancelPair()
    device.pair()
  }

  // Once the device being paired is paired, trusts it (so it can reconnect
  // by itself later) and connects it, unless pairing already did (many
  // devices connect as they pair); forgets it if the pairing failed.
  function finishPairing() {
    const device = root.pairingDevice
    if (device === null || device.pairing) return
    root.pairingDevice = null
    if (!device.paired) return
    device.trusted = true
    if (!device.connected) device.connect()
  }

  Connections {
    target: root.pairingDevice

    function onPairedChanged() {
      root.finishPairing()
    }

    function onPairingChanged() {
      root.finishPairing()
    }
  }

  // The adapter scans for devices while the menu searches (and Bluetooth is
  // on), so its list of nearby devices fills in. Scanning takes airtime from
  // the connected devices, so the search ends as the menu closes, which stops
  // the scan. It also pauses while a device pairs: a scan running alongside
  // makes the pairing and the connection after it fail.
  Binding {
    target: root.adapter
    property: "discovering"
    value: true
    when: menu.open && root.on && root.scanning && root.pairingDevice === null
  }

  Connections {
    target: menu

    function onOpenChanged() {
      if (!menu.open) root.scanning = false
    }
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

    // The title, with the switch turning Bluetooth on or off (not without an
    // adapter).
    MenuSwitchHeading {
      title: true
      text: I18n.tr("settings.widget.bluetooth")
      checked: root.on
      switchEnabled: root.adapter !== null
      onToggled: root.adapter.enabled = !root.adapter.enabled

      // Hovering any entry but a device closes the open device submenu.
      HoverHandler {
        onHoveredChanged: if (hovered) menu.activeEntry = null
      }
    }

    PowerMenuOption {
      enabled: root.on
      label: I18n.tr(root.adapter?.discoverable ? "bluetooth.hide" : "bluetooth.discoverable")

      HoverHandler {
        onHoveredChanged: if (hovered) menu.activeEntry = null
      }
      onClicked: {
        menu.open = false
        root.adapter.discoverable = !root.adapter.discoverable
      }
    }

    MenuSeparator {
      visible: root.pairedDevices.length > 0
    }

    // The paired devices, the connected ones first (with a link and their
    // battery). Hovering or clicking one opens its submenu beside the menu:
    // Connect or Disconnect, and Forget, which asks for a second click
    // first (forgetting a keyboard or a mouse means pairing it again).
    Repeater {
      model: root.pairedDevices

      Item {
        id: deviceRow

        required property var modelData
        // Whether its Forget was clicked once, for a few seconds.
        property bool confirmingForget: false

        width: deviceOption.width
        height: deviceOption.height

        HoverHandler {
          onHoveredChanged: if (hovered) menu.activeEntry = deviceRow
        }

        PowerMenuOption {
          id: deviceOption
          // Lit while its submenu is open.
          active: menu.activeEntry === deviceRow
          icon: deviceRow.modelData.connected ? "󰂱" : "󰂯"
          label: root.describe(deviceRow.modelData) + "  ›"
          onClicked: menu.activeEntry = deviceRow
        }

        Timer {
          id: forgetTimer
          interval: 3000
          onTriggered: deviceRow.confirmingForget = false
        }

        // Its submenu, created the first time it opens and then kept, as
        // the tray's are: the rows are rebuilt whenever the adapter's device
        // list changes (as a scan finds devices), and a submenu created with
        // each row counted as shown for a moment, throwing the bar's input
        // mask around as the list filled in.
        Loader {
          id: submenuLoader
          active: false
          sourceComponent: Component {
            PopupMenu {
              anchorItem: deviceRow
              parentMenu: menu
              // The menu already closes on a click outside, taking it along.
              grabFocus: false
              open: menu.open && menu.activeEntry === deviceRow
              onOpenChanged: if (!open) deviceRow.confirmingForget = false

              PowerMenuOption {
                enabled: root.on
                label: I18n.tr(deviceRow.modelData.connected ? "bluetooth.disconnect" : "bluetooth.connect")
                onClicked: {
                  menu.open = false
                  if (deviceRow.modelData.connected) deviceRow.modelData.disconnect()
                  else deviceRow.modelData.connect()
                }
              }

              PowerMenuOption {
                active: deviceRow.confirmingForget
                label: I18n.tr(deviceRow.confirmingForget ? "bluetooth.forgetConfirm" : "bluetooth.forget")
                onClicked: {
                  if (!deviceRow.confirmingForget) {
                    deviceRow.confirmingForget = true
                    forgetTimer.restart()
                    return
                  }
                  menu.open = false
                  deviceRow.modelData.forget()
                }
              }
            }
          }
        }

        Connections {
          target: menu

          function onActiveEntryChanged() {
            if (menu.activeEntry === deviceRow) submenuLoader.active = true
          }
        }
      }
    }

    MenuSeparator {}

    PowerMenuOption {
      enabled: root.on
      label: I18n.tr("bluetooth.sendFiles")
      onClicked: root.run(["blueman-sendto"])

      HoverHandler {
        onHoveredChanged: if (hovered) menu.activeEntry = null
      }
    }

    MenuSeparator {
      visible: root.on
    }

    // Add device… starts the scan, leaving the menu open: it gives way to a
    // heading (saying it's searching until a device turns up) over the
    // devices found nearby. A click pairs one, then connects it; it shows "…"
    // while it pairs and then moves up among the connected ones.
    PowerMenuOption {
      visible: root.on && !root.scanning
      label: I18n.tr("bluetooth.add")
      onClicked: root.scanning = true

      HoverHandler {
        onHoveredChanged: if (hovered) menu.activeEntry = null
      }
    }

    PowerMenuOption {
      visible: root.on && root.scanning
      enabled: false
      label: I18n.tr(root.nearby.length > 0 ? "bluetooth.nearby" : "bluetooth.searching")
    }

    Repeater {
      model: root.on && root.scanning ? root.nearby : []

      PowerMenuOption {
        required property var modelData
        label: modelData.deviceName + (modelData.pairing || modelData.state === BluetoothDeviceState.Connecting ? "  …" : "")
        onClicked: root.pair(modelData)

        HoverHandler {
          onHoveredChanged: if (hovered) menu.activeEntry = null
        }
      }
    }
  }

  // Whether Bluetooth is on, and the connected devices with their battery.
  HoverPopup {
    id: tooltip
    anchorItem: root
    alignCenter: true
    showWhen: !menu.open

    PopupTitle {
      text: I18n.tr("settings.widget.bluetooth")
    }

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
