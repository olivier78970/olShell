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
  // Set for a submenu: the menu it opens from. It then opens beside that
  // menu, level with its entry (anchorItem), rather than off the bar.
  property Item parentMenu: null
  // The entry of this menu whose submenu is open, if any (the last one
  // hovered or clicked); cleared as the menu closes.
  property Item activeEntry: null
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

  onVisibleChanged: {
    if (!root.visible) root.activeEntry = null
  }

  Binding {
    target: root
    property: "parent"
    value: root.host
    when: root.host !== null
  }

  // Where it goes in the layer (whose origin is on the bar's edge toward
  // the middle of the screen): off that edge (the pill's too, pills being as
  // tall as the bar) by the same gap as the panels attached to the bar
  // (Theme.panelOffset: the gap setting, or with none, flush, its border
  // overlapping the bar's instead of doubling up with it), and kept within
  // the bar horizontally. Taken from the bar's
  // edge rather than worked out from the widget's own height, which is often
  // fractional: the popup then landed part of a pixel into the bar, and that
  // row, drawn twice over, showed as a thin dark line. Looked up again as it
  // opens or resizes.
  x: {
    if (!root.host || !root.anchorItem) return 0
    if (root.parentMenu) {
      // A submenu: beside its menu, on the left (tray menus open from the
      // bar's right end), or on the right when there's no room there.
      const menu = root.parentMenu
      const left = menu.x - root.width - root.submenuGap
      return Math.round(left >= 0 ? left : menu.x + menu.width + root.submenuGap)
    }
    const p = root.anchorItem.mapToItem(root.host, 0, 0)
    let x
    if (root.alignCenter) x = p.x + (root.anchorItem.width - root.width) / 2
    else if (root.alignLeft) x = p.x + root.marginLeft
    else x = p.x + root.anchorItem.width - root.marginRight - root.width
    return Math.round(Math.max(0, Math.min(root.host.width - root.width, x)))
  }
  y: {
    if (!root.parentMenu) return root.barAtTop ? Theme.panelOffset() : -Theme.panelOffset() - root.height
    // A submenu: from the entry it opens from (see entryEdge), moved back
    // from the far edge of the screen only when there isn't even
    // minSubmenuHeight left past the entry.
    return Math.round(root.barAtTop ? Math.min(root.entryEdge, root.room - root.height)
      : Math.max(root.entryEdge - root.height, -root.room))
  }
  // How tall it can get: the room between the bar and the far edge of the
  // screen, less a margin. Longer entry lists scroll.
  readonly property real room: {
    const screen = root.host?.screen
    if (!screen) return 10000
    const margin = root.barAtTop ? Theme.barMarginTop : Theme.barMarginBottom
    return screen.height - margin - Theme.barHeight - 10
  }
  // For a submenu: where it starts, level with the entry it opens from -
  // its top with the entry's top, or on a bottom bar (where it grows
  // upward), its bottom with the entry's bottom. Looked up again as the menu
  // moves or scrolls.
  readonly property real entryEdge: {
    if (!root.parentMenu || !root.host || !root.anchorItem) return 0
    root.parentMenu.y
    root.parentMenu.scrollY
    return root.anchorItem.mapToItem(root.host, 0, root.barAtTop ? 0 : root.anchorItem.height).y
  }
  // How tall its entries want it to be.
  readonly property real contentHeight: column.implicitHeight + root.padding * 2
  // A submenu takes only the room left past its entry (scrolling the rest),
  // so a long one still starts at its entry - but at least this much, when
  // its entry is near the far edge of the screen.
  readonly property real minSubmenuHeight: 200
  readonly property real maxHeight: {
    if (!root.parentMenu) return root.room
    const left = root.barAtTop ? root.room - root.entryEdge : root.room + root.entryEdge
    return Math.min(root.room, Math.max(left, root.minSubmenuHeight))
  }
  // How far its entries are scrolled, for a submenu to follow its entry.
  readonly property real scrollY: flick.contentY
  // Space between a submenu and its menu: the same as between the bar and
  // the panels attached to it (Theme.panelOffset: the gap setting, or with
  // none, flush, their borders overlapping).
  readonly property real submenuGap: Theme.panelOffset()
  // Room around the entries, on every side.
  readonly property real padding: 8

  width: Math.ceil(column.implicitWidth + root.padding * 2)
  height: Math.ceil(Math.min(root.maxHeight, root.contentHeight))

  Item {
    id: surface
    anchors.fill: parent
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      // Flush with the bar (no gap set, see Theme.attachedCorner), both
      // corners against it are squared off so the popup flows out of the
      // bar (and its widget's pill, see Pill.flattenPopupCorner), like the
      // attached panels. A submenu, beside its menu rather than against the
      // bar, keeps its full radius.
      topLeftRadius: !root.parentMenu && Theme.attachedCorner(radius, true) === 0 ? 0 : radius
      topRightRadius: !root.parentMenu && Theme.attachedCorner(radius, true) === 0 ? 0 : radius
      bottomLeftRadius: !root.parentMenu && Theme.attachedCorner(radius, false) === 0 ? 0 : radius
      bottomRightRadius: !root.parentMenu && Theme.attachedCorner(radius, false) === 0 ? 0 : radius
      color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
      border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
      border.width: Theme.borderWidth
    }

    HoverHandler {
      id: hover
    }

    // Scrolls (mouse wheel, or dragging) when the entries don't all fit.
    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: root.padding
      contentWidth: column.implicitWidth
      contentHeight: column.implicitHeight
      interactive: flick.contentHeight > flick.height
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      Column {
        id: column
        spacing: 6
      }
    }

    // A slim scroll position indicator, in the right padding, while it scrolls.
    Rectangle {
      visible: flick.interactive
      x: parent.width - root.padding / 2 - width / 2
      y: root.padding + flick.visibleArea.yPosition * flick.height
      width: 3
      height: flick.visibleArea.heightRatio * flick.height
      radius: width / 2
      color: Theme.textColor
      opacity: 0.35
    }
  }
}
