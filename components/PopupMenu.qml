import QtQuick
import Quickshell
import qs.config

// Rounded popup panel anchored below a widget, styled to match the bar's
// pills. Put PowerMenuOption (or similar) rows inside it.
PopupWindow {
  id: root

  default property alias content: column.data
  property Item anchorItem
  // Right-align below the widget by default (for widgets in the bar's
  // right area); set true for widgets in the left area to left-align.
  property bool alignLeft: false
  // Center below the widget instead (overrides alignLeft).
  property bool alignCenter: false
  // True while the pointer is over the popup itself.
  readonly property bool containsMouse: hover.hovered

  anchor.item: anchorItem
  anchor.edges: alignCenter ? Edges.Bottom : Edges.Bottom | (alignLeft ? Edges.Left : Edges.Right)
  anchor.gravity: alignCenter ? Edges.Bottom : Edges.Bottom | (alignLeft ? Edges.Right : Edges.Left)
  // Widgets are vertically centered within their (taller) pill, so their
  // own bottom edge sits above the pill's. Push the anchor's bottom edge
  // down by that same gap so the popup starts flush with the pill/bar
  // bottom instead of the widget's.
  anchor.margins.bottom: anchorItem ? -(Theme.pillHeight() - anchorItem.height) / 2 - 5 : 0
  grabFocus: true
  visible: false

  implicitWidth: column.implicitWidth + 16
  implicitHeight: column.implicitHeight + 16
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    // The corner touching the widget's pill is squared off so they flow
    // together (not when centered).
    topLeftRadius: alignLeft && !alignCenter ? 0 : radius
    topRightRadius: !alignLeft && !alignCenter ? 0 : radius
    color: Theme.pillColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth
    opacity: Theme.widgetOpacity

    HoverHandler {
      id: hover
    }

    Column {
      id: column
      anchors.centerIn: parent
      spacing: 6
    }
  }
}
