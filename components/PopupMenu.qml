import QtQuick
import Quickshell
import qs.config

// Rounded popup panel anchored below a widget (above it on a bottom bar, and
// beside it, level with it, on a side bar), styled to match the bar's pills.
// Put PowerMenuOption (or similar) rows inside it. Open or close it with
// `open`: it slides out from under the bar (a submenu from under its menu)
// and fades in, and back as it closes, staying `visible` until it's in.
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
  // right area); set true for widgets in the left area to left-align. (On a
  // side bar, a popup is always centered on its widget's height instead.)
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
  // The submenu open beside this menu, if any (each one says so itself).
  property Item openSubmenu: null
  // True while the pointer is over the popup itself.
  readonly property bool containsMouse: hover.hovered
  // Whether it's open (see above).
  property bool open: false
  // How far out it is, from 0 (in) to 1 (all out), easing toward `open`.
  property real progress: root.open ? 1 : 0

  Behavior on progress {
    NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutCubic }
  }

  // Where its surface is drawn, back toward the bar (or, for a submenu, its
  // menu) by the part not out yet.
  readonly property point slide: {
    const hidden = 1 - root.progress
    if (root.parentMenu) return Qt.point((root.x > root.parentMenu.x ? -1 : 1) * hidden * root.width, 0)
    if (Theme.barVertical) return Qt.point((root.barAtLeft ? -1 : 1) * hidden * root.width, 0)
    return Qt.point(0, (root.barAtTop ? -1 : 1) * hidden * root.height)
  }

  readonly property bool barAtTop: Theme.barPosition !== "bottom"
  // Whether the bar stands against the left edge, where popups open to its
  // right (to its left, against the right edge).
  readonly property bool barAtLeft: Theme.barPosition === "left"
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
      root.open = false
    }
  }

  // Drawn while open, and while sliding back in; fading along.
  visible: root.open || root.progress > 0
  opacity: root.progress

  onOpenChanged: {
    if (!root.open) root.activeEntry = null
    if (root.parentMenu) {
      if (root.open) root.parentMenu.openSubmenu = root
      else if (root.parentMenu.openSubmenu === root) root.parentMenu.openSubmenu = null
    }
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
  // the bar along its length. Taken from the bar's
  // edge rather than worked out from the widget's own height, which is often
  // fractional: the popup then landed part of a pixel into the bar, and that
  // row, drawn twice over, showed as a thin dark line. Looked up again as it
  // opens or resizes.
  x: {
    // Read so it's looked up again each time it opens: the widget can have
    // moved in the bar since (layout changed in the settings), which nothing
    // below would otherwise notice.
    root.open
    if (!root.host || !root.anchorItem) return 0
    if (root.parentMenu) {
      const menu = root.parentMenu
      // On a side bar: beside its menu, further from the bar.
      if (Theme.barVertical) return Math.round(root.barAtLeft ? menu.x + menu.width + root.submenuGap : menu.x - root.width - root.submenuGap)
      // A submenu: beside its menu, on the left (tray menus open from the
      // bar's right end), or on the right when there's no room there.
      const left = menu.x - root.width - root.submenuGap
      return Math.round(left >= 0 ? left : menu.x + menu.width + root.submenuGap)
    }
    // Off a side bar's edge, like below a top bar's.
    if (Theme.barVertical) return root.barAtLeft ? Theme.panelOffset() : -Theme.panelOffset() - root.width
    const p = root.anchorItem.mapToItem(root.host, 0, 0)
    let x
    if (root.alignCenter) x = p.x + (root.anchorItem.width - root.width) / 2
    else if (root.alignLeft) x = p.x + root.marginLeft
    else x = p.x + root.anchorItem.width - root.marginRight - root.width
    return root.withinBar(x, root.width)
  }
  y: {
    if (Theme.barVertical) {
      root.open
      if (!root.host || !root.anchorItem) return 0
      // A submenu: level with the entry it opens from, moved back up only as
      // far as it needs to end with the bar.
      if (root.parentMenu) return Math.round(Math.max(root.host.barStart, Math.min(root.entryEdge, root.host.barEnd - root.height)))
      // Centered on its widget, within the bar.
      const p = root.anchorItem.mapToItem(root.host, 0, 0)
      return root.withinBar(p.y + (root.anchorItem.height - root.height) / 2, root.height)
    }
    if (!root.parentMenu) return root.barAtTop ? Theme.panelOffset() : -Theme.panelOffset() - root.height
    // A submenu: from the entry it opens from (see entryEdge), moved back
    // from the far edge of the screen only when there isn't even
    // minSubmenuHeight left past the entry.
    return Math.round(root.barAtTop ? Math.min(root.entryEdge, root.room - root.height)
      : Math.max(root.entryEdge - root.height, -root.room))
  }
  // Where a popup `size` long, starting at `start` along the bar, goes to stay
  // within the bar; snapped to either end of it from a couple of pixels off,
  // which Qt rounding the widget's centered position in its pill can leave it
  // short by, so it's seen as reaching that end (see Bar.qml's
  // popupLayer.atStartEnd).
  function withinBar(start, size) {
    const first = root.host.barStart
    const last = root.host.barEnd - size
    let place = Math.max(first, Math.min(last, start))
    if (place - first < 2) place = first
    if (last - place < 2) place = last
    return Math.round(place)
  }

  // How tall it can get: the room between the bar and the far edge of the
  // screen, less a margin (on a side bar, the bar's own length). Longer
  // entry lists scroll.
  readonly property real room: {
    if (Theme.barVertical) return root.host ? root.host.barEnd - root.host.barStart : 10000
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
    root.open
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
    const left = Theme.barVertical ? (root.host ? root.host.barEnd - root.entryEdge : root.room)
      : root.barAtTop ? root.room - root.entryEdge : root.room + root.entryEdge
    return Math.min(root.room, Math.max(left, root.minSubmenuHeight))
  }
  // How far its entries are scrolled, for a submenu to follow its entry.
  readonly property real scrollY: flick.contentY
  // Space between a submenu and its menu: the same as between the bar and
  // the panels attached to it (Theme.panelOffset: the gap setting, or with
  // none, flush, their borders overlapping).
  readonly property real submenuGap: Theme.panelOffset()
  // For a submenu with no gap set: whether its menu is flush against its
  // left side (it opened on the menu's right) or its right one.
  readonly property bool flushLeft: root.parentMenu !== null && Theme.panelGap <= 0 && root.x > root.parentMenu.x
  readonly property bool flushRight: root.parentMenu !== null && Theme.panelGap <= 0 && root.x < root.parentMenu.x
  // And whether its top and bottom corners on that side actually touch the
  // menu (a long submenu can reach past its menu's end).
  readonly property bool topTouchesMenu: root.parentMenu !== null && root.y >= root.parentMenu.y && root.y <= root.parentMenu.y + root.parentMenu.height
  readonly property bool bottomTouchesMenu: root.parentMenu !== null && root.y + root.height >= root.parentMenu.y && root.y + root.height <= root.parentMenu.y + root.parentMenu.height
  // For a menu with a submenu open flush against its left or right side:
  // whether its own top and bottom corners on that side touch the submenu
  // (which can reach past this menu's end), and so are squared off too.
  readonly property Item flushSubmenu: root.openSubmenu && (root.openSubmenu.flushLeft || root.openSubmenu.flushRight) ? root.openSubmenu : null
  readonly property bool topTouchesSubmenu: root.flushSubmenu !== null && root.y >= root.flushSubmenu.y && root.y <= root.flushSubmenu.y + root.flushSubmenu.height
  readonly property bool bottomTouchesSubmenu: root.flushSubmenu !== null && root.y + root.height >= root.flushSubmenu.y && root.y + root.height <= root.flushSubmenu.y + root.flushSubmenu.height
  // The submenu is on this menu's right when it's flush on its own left.
  readonly property bool submenuOnRight: root.flushSubmenu !== null && root.flushSubmenu.flushLeft
  readonly property bool submenuOnLeft: root.flushSubmenu !== null && root.flushSubmenu.flushRight
  // Room around the entries, on every side.
  readonly property real padding: 8

  width: Math.ceil(column.implicitWidth + root.padding * 2)
  height: Math.ceil(Math.min(root.maxHeight, root.contentHeight))

  // Curves it out of the bar when flush against it (not a submenu, beside
  // its menu), on each side that isn't flush with an end of the bar, where
  // the bar's own corner is squared off instead (see Bar.qml's popupLayer).
  BarFillets {
    visible: !root.parentMenu && root.host !== null
    color: background.color
    borderColor: background.border.color
    showStart: root.host !== null && (Theme.barVertical ? root.y : root.x) > root.host.barStart + 0.5
    showEnd: root.host !== null && (Theme.barVertical ? root.y + root.height : root.x + root.width) < root.host.barEnd - 0.5
  }

  // For a submenu flush against its menu (no gap set): concave corners
  // where one of the two runs past the other's end, curving from the longer
  // one's side into the shorter one's end, so they read as one shape: above
  // and below the submenu when its menu is longer, above and below the menu
  // where the submenu is. Each kept small enough to stay off the rounded
  // corner of the side it curves from.
  readonly property bool curvesActive: root.parentMenu !== null && (root.flushLeft || root.flushRight) && Theme.curvedJoins
  readonly property real curveSize: Theme.joinRadius
  // On which side of its menu it is, and the shared edge, in its own
  // coordinates; and where its menu starts and ends, in the same ones.
  readonly property bool onMenuLeft: root.flushRight
  readonly property real sharedEdge: root.onMenuLeft ? root.width : 0
  readonly property real menuTop: root.parentMenu ? root.parentMenu.y - root.y : 0
  readonly property real menuBottom: root.parentMenu ? root.parentMenu.y + root.parentMenu.height - root.y : 0
  // The corner radii of the menu's and its own sides facing each other.
  readonly property real menuCornerTop: !root.parentMenu ? 0 : root.onMenuLeft ? root.parentMenu.cornerTopLeft : root.parentMenu.cornerTopRight
  readonly property real menuCornerBottom: !root.parentMenu ? 0 : root.onMenuLeft ? root.parentMenu.cornerBottomLeft : root.parentMenu.cornerBottomRight
  readonly property real ownCornerTop: root.onMenuLeft ? root.cornerTopRight : root.cornerTopLeft
  readonly property real ownCornerBottom: root.onMenuLeft ? root.cornerBottomRight : root.cornerBottomLeft

  // Above it, from its menu's side (the menu starts higher).
  Fillet {
    size: Math.min(root.curveSize, -root.menuTop - root.menuCornerTop)
    visible: root.curvesActive && size >= 1
    x: root.onMenuLeft ? root.sharedEdge - size : 0
    y: -size
    color: background.color
    borderColor: background.border.color
    mirrorX: !root.onMenuLeft
    mirrorY: true
  }

  // Above its menu, from its own side (it starts higher).
  Fillet {
    size: Math.min(root.curveSize, root.menuTop - root.ownCornerTop)
    visible: root.curvesActive && size >= 1
    x: root.onMenuLeft ? root.sharedEdge : -size
    y: root.menuTop - size
    color: background.color
    borderColor: background.border.color
    mirrorX: root.onMenuLeft
    mirrorY: true
  }

  // Below it, from its menu's side (the menu ends lower).
  Fillet {
    size: Math.min(root.curveSize, root.menuBottom - root.height - root.menuCornerBottom)
    visible: root.curvesActive && size >= 1
    x: root.onMenuLeft ? root.sharedEdge - size : 0
    y: root.height
    color: background.color
    borderColor: background.border.color
    mirrorX: !root.onMenuLeft
  }

  // Below its menu, from its own side (it ends lower).
  Fillet {
    size: Math.min(root.curveSize, root.height - root.menuBottom - root.ownCornerBottom)
    visible: root.curvesActive && size >= 1
    x: root.onMenuLeft ? root.sharedEdge : -size
    y: root.menuBottom
    color: background.color
    borderColor: background.border.color
    mirrorX: root.onMenuLeft
  }

  // Its corner radii, for a submenu's curves to keep clear of them.
  readonly property real cornerTopLeft: background.topLeftRadius
  readonly property real cornerTopRight: background.topRightRadius
  readonly property real cornerBottomLeft: background.bottomLeftRadius
  readonly property real cornerBottomRight: background.bottomRightRadius

  // Clips the surface at the popup's own edges (the bar's, on the side
  // against it) while it slides out or back in (see slide).
  Item {
    anchors.fill: parent
    clip: root.progress < 1

    Item {
      id: surface
      anchors.fill: parent
      clip: true
      transform: Translate {
        x: root.slide.x
        y: root.slide.y
      }

      Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.radiusFor(height)
        // Flush with the bar (no gap set, see Theme.attachedCorner), both
        // corners against it are squared off so the popup flows out of the
        // bar (and the bar's or its end pill's corner, see Bar.qml's popupLayer), like the
        // attached panels. A submenu squares off, the same way, those on the
        // side against its menu that actually touch it instead, and so does
        // the menu, those on the side against its submenu that touch it.
        topLeftRadius: (root.flushLeft && root.topTouchesMenu) || (root.submenuOnLeft && root.topTouchesSubmenu) || (!root.parentMenu && Theme.attachedCorner(radius, "topLeft") === 0) ? 0 : radius
        topRightRadius: (root.flushRight && root.topTouchesMenu) || (root.submenuOnRight && root.topTouchesSubmenu) || (!root.parentMenu && Theme.attachedCorner(radius, "topRight") === 0) ? 0 : radius
        bottomLeftRadius: (root.flushLeft && root.bottomTouchesMenu) || (root.submenuOnLeft && root.bottomTouchesSubmenu) || (!root.parentMenu && Theme.attachedCorner(radius, "bottomLeft") === 0) ? 0 : radius
        bottomRightRadius: (root.flushRight && root.bottomTouchesMenu) || (root.submenuOnRight && root.bottomTouchesSubmenu) || (!root.parentMenu && Theme.attachedCorner(radius, "bottomRight") === 0) ? 0 : radius
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
}
