import QtQuick
import Quickshell
import Quickshell.Networking
import qs.components
import qs.config
import qs.services

// Network connection icon, doing what nm-applet's tray icon does: the
// wired plug or the Wi-Fi signal while connected (in the warning color when
// the connection doesn't reach the internet), crossed out otherwise. Hovering
// it shows what it's connected to, and a click (either button) opens a menu to
// connect or disconnect the wired network, pick a Wi-Fi network, reach a
// hidden one or create one, switch VPN connections, turn networking and Wi-Fi
// on or off, see the connection's details and edit the connections. Reads
// Quickshell's Networking module, and NetworkManager through nmcli for the rest
// (services/NetworkManager.qml).
Item {
  id: root

  // The wired and Wi-Fi devices.
  readonly property var devices: Networking.devices.values
  readonly property var wiredDevices: root.devices.filter(device => device.type === DeviceType.Wired)
  readonly property var wifiDevice: root.devices.find(device => device.type === DeviceType.Wifi) ?? null
  // The Wi-Fi networks in range, the strongest first, and the one connected.
  readonly property var wifiNetworks: root.wifiDevice
    ? root.wifiDevice.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength).slice(0, root.maxNetworks)
    : []
  readonly property var wifiConnected: root.wifiDevice ? root.wifiDevice.networks.values.find(network => network.connected) ?? null : null
  readonly property var wiredConnected: root.wiredDevices.find(device => device.connected) ?? null
  // How many Wi-Fi networks the menu lists at most.
  readonly property int maxNetworks: 8
  // Connected, but without a full way to the internet.
  readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited
    || Networking.connectivity === NetworkConnectivity.Portal
    || Networking.connectivity === NetworkConnectivity.None
  // A Wi-Fi network being connected to: the icon then fills its signal bars
  // one after the other, over and over, until it's done.
  readonly property bool wifiConnecting: root.wifiDevice !== null
    && root.wifiDevice.networks.values.some(network => network.state === ConnectionState.Connecting)
  // The bars shown in that animation (0 to 3), moved on by connectingTimer.
  property int connectingFrame: 0

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  // The Wi-Fi signal glyph for a strength from 0 to 1.
  function signalIcon(strength) {
    return strength > 0.75 ? "󰤨" : strength > 0.5 ? "󰤥" : strength > 0.25 ? "󰤢" : "󰤟"
  }

  // The name of the connection active on a device, as NetworkManager has it
  // ("Wired connection 1"); the device's own name while nmcli hasn't said.
  function connectionName(device) {
    return NetworkManager.details.find(detail => detail.device === device.name)?.connection ?? device.name
  }

  // A Wi-Fi network's strength in percent.
  function percent(network) {
    return Math.round(network.signalStrength * 100)
  }

  ThemedText {
    id: icon
    anchors.centerIn: parent
    text: !NetworkManager.networkingEnabled ? "󰲛"
      : root.wifiConnecting ? root.signalIcon((root.connectingFrame + 0.5) / 4)
      : root.wiredConnected ? "󰈀"
      : root.wifiConnected ? root.signalIcon(root.wifiConnected.signalStrength)
      : root.wifiDevice ? "󰤮" : "󰈂"
    color: root.limited && (root.wiredConnected || root.wifiConnected) ? Theme.warningColor : Theme.textColor
    opacity: root.wiredConnected || root.wifiConnected || root.wifiConnecting ? 1 : 0.5
    sizeScale: 1.4
  }

  Timer {
    id: connectingTimer
    interval: 300
    repeat: true
    running: root.wifiConnecting
    onRunningChanged: root.connectingFrame = 0
    onTriggered: root.connectingFrame = (root.connectingFrame + 1) % 4
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (!menu.visible) NetworkManager.refresh()
      menu.visible = !menu.visible
    }
    onEntered: {
      NetworkManager.refresh()
      tooltip.hoverEntered()
    }
    onExited: tooltip.hoverExited()
  }

  // The Wi-Fi scans while the menu is open, so its list is fresh.
  Binding {
    target: root.wifiDevice
    property: "scannerEnabled"
    value: menu.visible
    when: root.wifiDevice !== null
  }

  // Connects to a Wi-Fi network: straight away when it's open or known,
  // otherwise asking for its password first (in a terminal).
  function connectWifi(network) {
    menu.visible = false
    if (network.known || network.security === WifiSecurityType.Open) network.connect()
    else NetworkManager.connectWithPassword(network.name)
  }

  // Runs a menu entry's action and closes the menu.
  function pick(action) {
    menu.visible = false
    action()
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

  // The title of a group of menu entries.
  component MenuHeading: PowerMenuOption {
    enabled: false
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    // Each wired device: its connection (a click connects it) and, while
    // connected, Disconnect.
    Repeater {
      model: NetworkManager.networkingEnabled ? root.wiredDevices : []

      Column {
        id: wired

        required property var modelData
        readonly property var network: wired.modelData.network

        spacing: 6

        MenuHeading {
          label: root.wiredDevices.length > 1 ? I18n.tr("network.wiredDevice", wired.modelData.name) : I18n.tr("network.wired")
        }

        PowerMenuOption {
          visible: wired.network !== null
          active: wired.network?.connected ?? false
          icon: "󰈀"
          label: root.connectionName(wired.modelData) + (wired.network?.stateChanging ? "  …" : "")
          onClicked: {
            menu.visible = false
            if (!wired.network.connected) wired.network.connect()
          }
        }

        PowerMenuOption {
          visible: wired.modelData.connected
          label: I18n.tr("network.disconnect")
          onClicked: root.pick(() => wired.modelData.disconnect())
        }

        MenuSeparator {}
      }
    }

    // The Wi-Fi networks in range, the connected one lit; a click connects.
    MenuHeading {
      visible: root.wifiDevice !== null && NetworkManager.networkingEnabled
      label: I18n.tr("network.wifi")
    }

    MenuHeading {
      visible: root.wifiDevice !== null && NetworkManager.networkingEnabled && (!Networking.wifiEnabled || root.wifiNetworks.length === 0)
      label: I18n.tr(Networking.wifiEnabled ? "network.wifiNone" : "network.wifiOff")
    }

    Repeater {
      model: NetworkManager.networkingEnabled && Networking.wifiEnabled ? root.wifiNetworks : []

      PowerMenuOption {
        required property var modelData
        active: modelData.connected
        icon: root.signalIcon(modelData.signalStrength)
        label: modelData.name + (modelData.security !== WifiSecurityType.Open ? "  󰌾" : "") + (modelData.stateChanging ? "  …" : "")
        onClicked: {
          if (modelData.connected) menu.visible = false
          else root.connectWifi(modelData)
        }
      }
    }

    PowerMenuOption {
      visible: root.wifiConnected !== null
      label: I18n.tr("network.disconnect")
      onClicked: root.pick(() => root.wifiDevice.disconnect())
    }

    MenuSeparator {
      visible: root.wifiDevice !== null && NetworkManager.networkingEnabled
    }

    PowerMenuOption {
      visible: root.wifiDevice !== null
      enabled: NetworkManager.networkingEnabled && Networking.wifiEnabled
      label: I18n.tr("network.hidden")
      onClicked: root.pick(() => NetworkManager.connectHidden())
    }

    PowerMenuOption {
      visible: root.wifiDevice !== null
      enabled: NetworkManager.networkingEnabled && Networking.wifiEnabled
      label: I18n.tr("network.createWifi")
      onClicked: root.pick(() => NetworkManager.createConnection("802-11-wireless"))
    }

    MenuSeparator {
      visible: root.wifiDevice !== null
    }

    // The VPN connections, the active ones lit: a click switches one.
    MenuHeading {
      label: I18n.tr("network.vpn")
    }

    Repeater {
      model: NetworkManager.vpns

      PowerMenuOption {
        required property var modelData
        enabled: NetworkManager.networkingEnabled
        active: modelData.active
        label: modelData.name
        onClicked: root.pick(() => NetworkManager.setVpn(modelData.uuid, !modelData.active))
      }
    }

    PowerMenuOption {
      label: I18n.tr("network.addVpn")
      onClicked: root.pick(() => NetworkManager.createConnection(""))
    }

    MenuSeparator {}

    PowerMenuOption {
      icon: NetworkManager.networkingEnabled ? "󰄲" : "󰄱"
      label: I18n.tr("network.enableNetworking")
      onClicked: root.pick(() => NetworkManager.setNetworking(!NetworkManager.networkingEnabled))
    }

    PowerMenuOption {
      visible: root.wifiDevice !== null
      enabled: NetworkManager.networkingEnabled && Networking.wifiHardwareEnabled
      icon: Networking.wifiEnabled ? "󰄲" : "󰄱"
      label: I18n.tr("network.enableWifi")
      onClicked: root.pick(() => Networking.wifiEnabled = !Networking.wifiEnabled)
    }

    MenuSeparator {}

    PowerMenuOption {
      enabled: NetworkManager.details.length > 0
      label: I18n.tr("network.info")
      onClicked: {
        menu.visible = false
        info.visible = true
      }
    }

    PowerMenuOption {
      label: I18n.tr("network.edit")
      onClicked: root.pick(() => NetworkManager.editConnections())
    }
  }

  // The details of each active connection (the menu's Connection
  // information), until a click elsewhere.
  PopupMenu {
    id: info
    anchorItem: root
    alignCenter: true

    Repeater {
      model: NetworkManager.details

      Column {
        id: detail

        required property var modelData
        required property int index
        // Label and value pairs, those with a value.
        readonly property var rows: [
          [I18n.tr("network.info.device"), detail.modelData.device],
          [I18n.tr("network.info.ipv4"), detail.modelData.ipv4.join("\n")],
          [I18n.tr("network.info.gateway"), detail.modelData.gateway],
          [I18n.tr("network.info.dns"), detail.modelData.dns.join("\n")],
          [I18n.tr("network.info.ipv6"), detail.modelData.ipv6.join("\n")]
        ].filter(pair => pair[1] !== "")

        topPadding: detail.index > 0 ? 10 : 0
        leftPadding: 8
        rightPadding: 8
        spacing: 4

        ThemedText {
          text: detail.modelData.connection
          font.bold: true
        }

        Grid {
          columns: 2
          columnSpacing: 16
          rowSpacing: 4

          Repeater {
            model: detail.rows.reduce((cells, pair) => cells.concat(pair), [])

            ThemedText {
              required property string modelData
              required property int index
              text: modelData
              opacity: index % 2 === 0 ? 0.6 : 1
              sizeScale: 0.85
            }
          }
        }
      }
    }
  }

  // What it's connected to, with the address.
  HoverPopup {
    id: tooltip
    anchorItem: root
    alignCenter: true
    showWhen: !menu.visible && !info.visible

    ThemedText {
      text: !NetworkManager.networkingEnabled ? I18n.tr("network.networkingOff")
        : root.wiredConnected ? I18n.tr("network.connectedWired", root.connectionName(root.wiredConnected))
        : root.wifiConnected ? I18n.tr("network.connectedWifi", root.wifiConnected.name, root.percent(root.wifiConnected))
        : I18n.tr("network.disconnected")
    }

    ThemedText {
      visible: root.limited && (root.wiredConnected !== null || root.wifiConnected !== null)
      text: I18n.tr("network.limited")
      color: Theme.warningColor
      sizeScale: 0.85
    }

    ThemedText {
      visible: text !== ""
      text: NetworkManager.details.map(detail => detail.ipv4[0] ?? "").filter(address => address !== "").join("\n")
      sizeScale: 0.85
      opacity: 0.7
    }
  }
}
