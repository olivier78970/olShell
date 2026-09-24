import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services

// Row of workspace indicators, 1 to WorkspaceRules.shownCount (the setting,
// or as many as the Hyprland config sets up). Click one to
// switch to it; the currently focused workspace is highlighted. The ones
// with no workspace rule in the Hyprland config (so most likely no
// keybinds either, see services/WorkspaceRules.qml) are in a darker
// warning red.
Row {
  id: root

  readonly property int workspaceCount: WorkspaceRules.shownCount
  readonly property int dotSize: 14
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
      readonly property bool configured: WorkspaceRules.configured.includes(wsId)

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
