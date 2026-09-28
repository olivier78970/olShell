import QtQuick
import qs.config

// Rounded pill container that groups a bar section's widgets in a row (a
// column on a side bar).
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

  // Square off the corner on the pill's start (left, or top on a side bar) or
  // end where a popup flush with it attaches, so the pill flows into it: the
  // one on the bar's inward side, where popups open (see
  // Theme.flatBarCorner).
  property bool flattenStartPopupCorner: false
  property bool flattenEndPopupCorner: false

  // As thick as the bar, and as long as its widgets plus the padding at
  // either end.
  implicitWidth: Theme.barVertical ? Theme.pillHeight() : row.implicitWidth + horizontalPadding * 2
  implicitHeight: Theme.barVertical ? row.implicitHeight + horizontalPadding * 2 : Theme.pillHeight()

  HoverHandler {
    id: pillHover
  }

  Rectangle {
    id: background
    anchors.fill: parent
    visible: Theme.barStyle !== "full"
    radius: Theme.radiusFor(Math.min(width, height))
    topLeftRadius: Theme.flatBarCorner("topLeft", root.flattenStartPopupCorner, root.flattenEndPopupCorner) ? 0 : radius
    topRightRadius: Theme.flatBarCorner("topRight", root.flattenStartPopupCorner, root.flattenEndPopupCorner) ? 0 : radius
    bottomLeftRadius: Theme.flatBarCorner("bottomLeft", root.flattenStartPopupCorner, root.flattenEndPopupCorner) ? 0 : radius
    bottomRightRadius: Theme.flatBarCorner("bottomRight", root.flattenStartPopupCorner, root.flattenEndPopupCorner) ? 0 : radius
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth
  }

  BarStack {
    id: row
    anchors.centerIn: parent
    gap: Theme.widgetSpacing
    stackGap: Theme.widgetSpacing
  }
}
