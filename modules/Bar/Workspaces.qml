import QtQuick
import Quickshell.Hyprland
import qs.config

// Fixed row of 5 workspace indicators. Click one to switch to it;
// the currently focused workspace is highlighted.
Row {
  id: root

  readonly property int workspaceCount: 5
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

      anchors.verticalCenter: parent.verticalCenter
      width: active ? root.dotSize * 2 : root.dotSize
      height: root.dotSize
      radius: Theme.radiusFor(height)
      color: active ? Theme.accentColor : Theme.borderColor

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
