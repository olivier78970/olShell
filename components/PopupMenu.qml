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

  // The bar's own edge, where the widget's pill is: below it normally, but
  // above it when the bar is at the bottom of the screen, so the popup
  // always opens toward the middle of the screen instead of off the edge.
  readonly property int barEdge: Theme.barPosition === "bottom" ? Edges.Top : Edges.Bottom

  anchor.item: anchorItem
  anchor.edges: alignCenter ? barEdge : barEdge | (alignLeft ? Edges.Left : Edges.Right)
  anchor.gravity: alignCenter ? barEdge : barEdge | (alignLeft ? Edges.Right : Edges.Left)
  // Widgets are vertically centered within their (taller) pill, so their own
  // near edge (bottom normally, top with the bar at the bottom) sits inside
  // the pill's. Push the anchor out by that same gap so the popup starts
  // flush with the pill/bar edge instead of the widget's, then in by the
  // border width so the popup's border overlaps the pill's instead of
  // doubling up with it.
  anchor.margins.bottom: anchorItem && root.barEdge === Edges.Bottom ? -(Theme.pillHeight() - anchorItem.height) / 2 + Theme.borderWidth : 0
  anchor.margins.top: anchorItem && root.barEdge === Edges.Top ? -(Theme.pillHeight() - anchorItem.height) / 2 + Theme.borderWidth : 0
  grabFocus: true
  visible: false

  implicitWidth: column.implicitWidth + 16
  implicitHeight: column.implicitHeight + 16
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    // The corner touching the widget's pill is squared off so they flow
    // together (not when centered): the popup's top corner, on the side
    // that isn't centered, when it opens below the bar; its bottom corner
    // when it opens above (the bar's at the bottom of the screen).
    topLeftRadius: root.barEdge === Edges.Bottom && alignLeft && !alignCenter ? 0 : radius
    topRightRadius: root.barEdge === Edges.Bottom && !alignLeft && !alignCenter ? 0 : radius
    bottomLeftRadius: root.barEdge === Edges.Top && alignLeft && !alignCenter ? 0 : radius
    bottomRightRadius: root.barEdge === Edges.Top && !alignLeft && !alignCenter ? 0 : radius
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth

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
