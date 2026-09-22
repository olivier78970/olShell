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

      // The bar's own background, the same color as its widget pills, shown
      // only in the "full" barStyle (the pills' own backgrounds go
      // transparent instead, see Pill.qml). Settings.barOpacity controls it.
      Rectangle {
        anchors.fill: parent
        visible: Theme.barStyle === "full"
        radius: Theme.radiusFor(height)
        color: Theme.pillColor
        border.color: Theme.outlineColor
        border.width: Theme.borderWidth
        opacity: Theme.barOpacity
      }

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
