import QtQuick
import Quickshell
import qs.config
import qs.services

// The pop-ups: the newest notifications, stacked in a corner or at the middle
// of an edge (or halfway down the left or right one) of the focused screen (Settings.notificationPosition;
// under the bar at the top). The newest is the one nearest the edge. The window
// is only as big as the pop-ups, so clicks elsewhere reach the windows below.
PanelWindow {
  id: root

  screen: Notifications.screen
  // With neither side anchored the window is centered.
  anchors {
    top: Notifications.atTop
    bottom: Notifications.atBottom
    left: Notifications.atLeft
    right: Notifications.atRight
  }
  margins.top: 10
  margins.bottom: 10
  margins.left: Theme.barMarginLeft
  margins.right: Theme.barMarginRight

  implicitWidth: 380
  implicitHeight: Math.max(1, column.implicitHeight)
  color: "transparent"
  aboveWindows: true
  focusable: false
  // Respects the bar's reserved room (so it starts under the bar) without
  // reserving any of its own.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  // Nothing to show: no window at all. The center shows them instead.
  visible: Notifications.popups.length > 0 && !NotificationCenterState.visible

  Column {
    id: column
    width: parent.width
    spacing: 10

    Repeater {
      model: ScriptModel {
        values: Notifications.atBottom ? Notifications.popups.slice().reverse() : Notifications.popups
      }

      NotificationCard {
        required property var modelData

        width: column.width
        entry: modelData
        toast: true
      }
    }
  }
}
