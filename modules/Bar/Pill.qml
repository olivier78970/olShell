import QtQuick
import qs.config

// Rounded pill container that groups a bar section's widgets in a row.
Rectangle {
  id: root

  default property alias content: row.data
  property int spacing: 10
  property int horizontalPadding: Theme.pillPadding

  // Square off the bottom-right corner, e.g. while a popup anchored to
  // this pill's right edge is open, so the pill flows into the popup.
  property bool flattenBottomRight: false

  implicitWidth: row.implicitWidth + horizontalPadding * 2
  implicitHeight: Theme.pillHeight()
  opacity: Theme.widgetOpacity
  radius: Theme.radiusFor(height)
  bottomRightRadius: flattenBottomRight ? 0 : radius
  color: Theme.pillColor
  border.color: Theme.outlineColor
  border.width: Theme.borderWidth

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.widgetSpacing
  }
}
