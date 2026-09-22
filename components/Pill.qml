import QtQuick
import qs.config

// Rounded pill container that groups a bar section's widgets in a row.
// Theme.widgetOpacity fades only the background/border, not the content, so
// text and icons stay fully readable even at a low widget opacity.
Item {
  id: root

  default property alias content: row.data
  property int spacing: 10
  property int horizontalPadding: Theme.pillPadding
  // True while the pointer is over the pill (padding included).
  readonly property bool hovered: pillHover.hovered

  // Square off the bottom-right corner, e.g. while a popup anchored to
  // this pill's right edge is open, so the pill flows into the popup.
  property bool flattenBottomRight: false

  implicitWidth: row.implicitWidth + horizontalPadding * 2
  implicitHeight: Theme.pillHeight()

  HoverHandler {
    id: pillHover
  }

  Rectangle {
    id: background
    anchors.fill: parent
    visible: Theme.barStyle !== "full"
    opacity: Theme.widgetOpacity
    radius: Theme.radiusFor(height)
    bottomRightRadius: root.flattenBottomRight ? 0 : radius
    color: Theme.pillColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.widgetSpacing
  }
}
