import QtQuick
import qs.config

// Rounded pill container that groups a bar section's widgets in a row.
// Theme.widgetOpacity fades only the background (and, unless
// Theme.borderOpaque is set, the border), not the content, so text and icons
// stay fully readable even at a low widget opacity.
Item {
  id: root

  default property alias content: row.data
  property int spacing: 10
  property int horizontalPadding: Theme.pillPadding
  // True while the pointer is over the pill (padding included).
  readonly property bool hovered: pillHover.hovered

  // Square off the corner on the pill's right (or left) end where a popup
  // flush with it attaches, so the pill flows into it: the bottom one
  // normally, or the top one with the bar at the bottom of the screen, where
  // popups open upward instead.
  property bool flattenRightPopupCorner: false
  property bool flattenLeftPopupCorner: false

  implicitWidth: row.implicitWidth + horizontalPadding * 2
  implicitHeight: Theme.pillHeight()

  HoverHandler {
    id: pillHover
  }

  Rectangle {
    id: background
    anchors.fill: parent
    visible: Theme.barStyle !== "full"
    radius: Theme.radiusFor(height)
    topRightRadius: root.flattenRightPopupCorner && Theme.barPosition === "bottom" ? 0 : radius
    bottomRightRadius: root.flattenRightPopupCorner && Theme.barPosition !== "bottom" ? 0 : radius
    topLeftRadius: root.flattenLeftPopupCorner && Theme.barPosition === "bottom" ? 0 : radius
    bottomLeftRadius: root.flattenLeftPopupCorner && Theme.barPosition !== "bottom" ? 0 : radius
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.widgetSpacing
  }
}
