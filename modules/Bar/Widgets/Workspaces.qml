import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

// Row of workspace indicators (a column on a side bar), 1 to
// WorkspaceRules.shownCount (the setting,
// or as many as the Hyprland config sets up). Click one to
// switch to it; the currently focused workspace is highlighted. The ones
// with no workspace rule in the Hyprland config (so most likely no
// keybinds either, see services/WorkspaceRules.qml) are in a darker
// warning red. The focused one is twice as long, along the bar.
BarStack {
  id: root

  readonly property int workspaceCount: WorkspaceRules.shownCount
  readonly property int dotSize: 14
  anchors.verticalCenter: parent.verticalCenter
  gap: 10
  stackGap: 10

  Repeater {
    model: root.workspaceCount

    Rectangle {
      id: delegate

      required property int index
      readonly property int wsId: index + 1
      readonly property bool active: Hyprland.focusedWorkspace !== null
        && Hyprland.focusedWorkspace.id === wsId
      readonly property bool configured: WorkspaceRules.configured.includes(wsId)

      width: active && !Theme.barVertical ? root.dotSize * 2 : root.dotSize
      height: active && Theme.barVertical ? root.dotSize * 2 : root.dotSize
      radius: Theme.radiusFor(Math.min(width, height))
      color: active ? Theme.accentColor : (configured ? Qt.darker(Theme.textColor, 2.5) : Qt.darker(Theme.warningColor, 2.5))

      Behavior on width {
        NumberAnimation { duration: 120 }
      }

      Behavior on height {
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
