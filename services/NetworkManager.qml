pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What the connection widget (modules/Bar/Widgets/ConnectionButton.qml)
// needs from NetworkManager beyond Quickshell's Networking module, through
// nmcli: whether networking is on, the details of the active connections,
// and the windows it opens (a password prompt, hidden
// networks, the connection editor). Read again by refresh(), which the widget
// calls as its menu or tooltip opens, and after each change it makes.
Singleton {
  id: root

  // Whether networking as a whole is on (nmcli networking).
  property bool networkingEnabled: true
  // The connected devices' details: [{ device, type, connection, ipv4,
  // gateway, dns, ipv6 }], each address list as an array.
  property var details: []

  function refresh() {
    networkingProc.running = true
    detailsProc.running = true
  }

  // nmcli with its output in English, since it is parsed.
  function nmcli(args) {
    return ["env", "LC_ALL=C", "nmcli"].concat(args)
  }

  // Runs an nmcli command, then reads everything again once it has had time
  // to take effect.
  function run(args) {
    Quickshell.execDetached(root.nmcli(args))
    refreshLater.restart()
  }

  function setNetworking(on) {
    root.networkingEnabled = on
    root.run(["networking", on ? "on" : "off"])
  }

  // Connects to a secured Wi-Fi network NetworkManager has no password for:
  // nmcli asks for it in a terminal. The name goes in as an argument.
  function connectWithPassword(ssid) {
    Quickshell.execDetached(Apps.terminalCommand(["sh", "-c", 'nmcli --ask device wifi connect "$1" || { printf "\\n%s" "$2"; read -r _; }', "sh", ssid, I18n.tr("network.pressEnter")], "quickshell-network", "nmcli"))
    refreshLater.restart()
  }

  // Connects to a hidden Wi-Fi network: its name and password are asked for
  // in a terminal.
  function connectHidden() {
    Quickshell.execDetached(Apps.terminalCommand(["sh", "-c", 'printf "%s" "$1"; read -r ssid && nmcli --ask device wifi connect "$ssid" hidden yes || { printf "\\n%s" "$2"; read -r _; }', "sh", I18n.tr("network.hiddenPrompt"), I18n.tr("network.pressEnter")], "quickshell-network", "nmcli"))
    refreshLater.restart()
  }

  // Opens NetworkManager's connection editor on the dialog creating a
  // connection (of `type`, or asking which).
  function createConnection(type) {
    Quickshell.execDetached(["nm-connection-editor", "--create"].concat(type ? ["--type=" + type] : []))
  }

  Timer {
    id: refreshLater
    interval: 1500
    onTriggered: root.refresh()
  }

  Process {
    id: networkingProc
    command: root.nmcli(["networking"])
    stdout: StdioCollector {
      onStreamFinished: root.networkingEnabled = this.text.trim() !== "disabled"
    }
  }

  Process {
    id: detailsProc
    command: root.nmcli(["-t", "-f", "GENERAL.DEVICE,GENERAL.TYPE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show"])
    stdout: StdioCollector {
      onStreamFinished: {
        // One block of lines per device, blank lines between them; the
        // address lists come as IP4.ADDRESS[1], IP4.ADDRESS[2]...
        const devices = []
        let current = null
        for (const line of this.text.split("\n")) {
          const separator = line.indexOf(":")
          if (separator < 0) continue
          const key = line.slice(0, separator).replace(/\[\d+\]$/, "")
          const value = line.slice(separator + 1)
          if (key === "GENERAL.DEVICE") {
            current = { device: value, type: "", connection: "", ipv4: [], gateway: "", dns: [], ipv6: [] }
            devices.push(current)
          } else if (!current || value === "" || value === "--") {
            continue
          } else if (key === "GENERAL.TYPE") current.type = value
          else if (key === "GENERAL.CONNECTION") current.connection = value
          else if (key === "IP4.ADDRESS") current.ipv4.push(value)
          else if (key === "IP4.GATEWAY") current.gateway = value
          else if (key === "IP4.DNS") current.dns.push(value)
          else if (key === "IP6.ADDRESS") current.ipv6.push(value)
        }
        root.details = devices.filter(device => device.connection !== "" && (device.type === "ethernet" || device.type === "wifi"))
      }
    }
  }
}
