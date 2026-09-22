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

      readonly property bool atTop: Theme.barPosition === "top"

      anchors {
        top: atTop
        bottom: !atTop
        left: true
        right: true
      }

      margins.top: atTop ? Theme.barMarginTop : 0
      margins.bottom: atTop ? 0 : Theme.barMarginBottom
      margins.left: Theme.barMarginLeft
      margins.right: Theme.barMarginRight

      implicitHeight: Theme.barHeight
      // The room the bar keeps free for itself: its height plus the margin
      // on the far side from the edge it's anchored to, so windows start
      // that much further away.
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: Theme.barHeight + (atTop ? Theme.barMarginBottom : Theme.barMarginTop)
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
        flattenPopupCorner: popupOpen
      }
    }
  }
}
