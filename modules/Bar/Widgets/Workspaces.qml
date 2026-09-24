import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Row of workspace indicators, 1 to Settings.workspaceCount. Click one to
// switch to it; the currently focused workspace is highlighted. The ones
// with no workspace rule in the Hyprland config (so most likely no
// keybinds either) are in a darker warning red.
Row {
  id: root

  readonly property int workspaceCount: Settings.workspaceCount
  readonly property int dotSize: 14
  // The ids of the workspaces the Hyprland config has a rule for.
  property var configured: []

  // Read at start and after each config reload, so adding a rule shows.
  Process {
    id: rulesProcess
    running: true
    command: ["hyprctl", "workspacerules", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.configured = JSON.parse(this.text).map(rule => Number(rule.workspaceString)).filter(id => Number.isInteger(id) && id > 0)
        } catch (e) {}
      }
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded") rulesProcess.running = true
    }
  }

  anchors.verticalCenter: parent.verticalCenter
  spacing: 10

  Repeater {
    model: root.workspaceCount

    Rectangle {
      id: delegate

      required property int index
      readonly property int wsId: index + 1
      readonly property bool active: Hyprland.focusedWorkspace !== null
        && Hyprland.focusedWorkspace.id === wsId
      readonly property bool configured: root.configured.includes(wsId)

      anchors.verticalCenter: parent.verticalCenter
      width: active ? root.dotSize * 2 : root.dotSize
      height: root.dotSize
      radius: Theme.radiusFor(height)
      color: active ? Theme.accentColor : (configured ? Qt.darker(Theme.textColor, 2.5) : Qt.darker(Theme.warningColor, 2.5))

      Behavior on width {
        NumberAnimation { duration: 120 }
      }

      MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=" + delegate.wsId + "})")
      }
    }
  }
}
