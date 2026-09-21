import Quickshell
import QtQuick
import qs.config

// Top bar, replicated across every connected screen.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      margins.top: Theme.barMarginTop
      margins.left: Theme.barMarginLeft
      margins.right: Theme.barMarginRight

      implicitHeight: Theme.barHeight
      // The room the bar keeps free for itself: its height plus the bottom
      // margin, so windows start that much lower.
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: Theme.barHeight + Theme.barMarginBottom
      color: "transparent"

      // Left widgets
      WidgetZone {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        widgets: Settings.layout.left
      }

      // Middle widgets
      WidgetZone {
        anchors.centerIn: parent
        widgets: Settings.layout.center
      }

      // Right widgets
      WidgetZone {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        widgets: Settings.layout.right
        flattenBottomRight: popupOpen
      }
    }
  }
}
