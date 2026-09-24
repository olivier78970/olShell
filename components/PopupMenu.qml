import QtQuick
import Quickshell
import qs.config

// Rounded popup panel anchored below a widget, styled to match the bar's
// pills. Put PowerMenuOption (or similar) rows inside it.
//
// Not a popup surface of its own: while shown, it's drawn inside its bar's
// own surface instead (see Bar.qml's popupLayer and config/BarSlots.qml), so
// bar and popup are blurred together, once. As a separate surface on top, its
// blur also picked up the bar's own fill right under it, which left the popup
// visibly darker along the seam.
Item {
  id: root

  default property alias content: column.data
  property Item anchorItem
  // Right-align below the widget by default (for widgets in the bar's
  // right area); set true for widgets in the left area to left-align.
  property bool alignLeft: false
  // Center below the widget instead (overrides alignLeft).
  property bool alignCenter: false
  // How far past the widget's own left/right edge the popup's matching edge
  // goes (negative: further out, e.g. -Theme.pillPadding to line up with the
  // pill's edge rather than the widget's).
  property real marginLeft: 0
  property real marginRight: 0
  // Closes on a click outside the bar and its popups.
  property bool grabFocus: true
  // True while the pointer is over the popup itself.
  readonly property bool containsMouse: hover.hovered

  readonly property bool barAtTop: Theme.barPosition !== "bottom"
  // The bar's popup layer this is drawn in, shown or not (so `visible`,
  // which moving it changes, never decides where it lives).
  readonly property Item host: {
    if (!root.anchorItem) return null
    const win = root.anchorItem.QsWindow.window
    return win ? BarSlots.popupLayerFor(win.screen) : null
  }

  // A click outside the bar and its popups closes it (see grabFocus).
  Connections {
    target: root.grabFocus ? root.host : null

    function onDismissed() {
      root.visible = false
    }
  }

  visible: false

  Binding {
    target: root
    property: "parent"
    value: root.host
    when: root.host !== null
  }

  // Where it goes in the layer (whose origin is on the bar's edge toward
  // the middle of the screen): off that edge (the pill's too, pills being as
  // tall as the bar), its border overlapping the bar's instead of doubling
  // up with it, and kept within the bar horizontally. Taken from the bar's
  // edge rather than worked out from the widget's own height, which is often
  // fractional: the popup then landed part of a pixel into the bar, and that
  // row, drawn twice over, showed as a thin dark line. Looked up again as it
  // opens or resizes.
  x: {
    if (!root.host || !root.anchorItem) return 0
    const p = root.anchorItem.mapToItem(root.host, 0, 0)
    let x
    if (root.alignCenter) x = p.x + (root.anchorItem.width - root.width) / 2
    else if (root.alignLeft) x = p.x + root.marginLeft
    else x = p.x + root.anchorItem.width - root.marginRight - root.width
    return Math.round(Math.max(0, Math.min(root.host.width - root.width, x)))
  }
  y: root.barAtTop ? -Theme.borderWidth : Theme.borderWidth - root.height

  width: Math.ceil(column.implicitWidth + 16)
  height: Math.ceil(column.implicitHeight + 16)

  Item {
    id: surface
    anchors.fill: parent
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      // Flush with the bar (no gap set, see Theme.attachedCorner), both
      // corners against it are squared off so the popup flows out of the
      // bar, like the attached panels. Otherwise only the corner touching
      // the widget's pill is (not when centered): the popup's top corner, on
      // the side that isn't centered, when it opens below the bar; its
      // bottom corner when it opens above (the bar's at the bottom of the
      // screen). And only in the "widgets" bar style, which has a pill to
      // flow into - "full" style's single bar-wide background has no
      // per-widget edge to match, so the popup keeps its full radius there.
      topLeftRadius: Theme.attachedCorner(radius, true) === 0 || (Theme.barStyle !== "full" && root.barAtTop && alignLeft && !alignCenter) ? 0 : radius
      topRightRadius: Theme.attachedCorner(radius, true) === 0 || (Theme.barStyle !== "full" && root.barAtTop && !alignLeft && !alignCenter) ? 0 : radius
      bottomLeftRadius: Theme.attachedCorner(radius, false) === 0 || (Theme.barStyle !== "full" && !root.barAtTop && alignLeft && !alignCenter) ? 0 : radius
      bottomRightRadius: Theme.attachedCorner(radius, false) === 0 || (Theme.barStyle !== "full" && !root.barAtTop && !alignLeft && !alignCenter) ? 0 : radius
      color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
      border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
      border.width: Theme.borderWidth
    }

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
