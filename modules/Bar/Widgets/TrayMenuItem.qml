import QtQuick
import qs.components
import qs.config

// One row in a tray item's context menu: a separator line, or a
// PowerMenuOption-styled clickable entry.
//
// An entry with children (marked "›") opens them in a submenu beside its
// menu (TraySubmenu) as it's hovered or clicked, and keeps it open until
// another entry of the same menu is hovered or the menu closes. Menus are
// plain items drawn in the bar (see components/PopupMenu.qml), so a submenu
// is just one more of them - which the popup surfaces menus used to be
// couldn't do: one anchored inside another never mapped.
Item {
  id: root

  required property var modelData
  // The menu this entry is in, and the top-level one it opened from.
  required property Item menu
  required property Item rootMenu

  readonly property bool hasSubmenu: root.modelData.hasChildren && !root.modelData.isSeparator
  // Whether its submenu is open (it's its menu's active entry).
  readonly property bool submenuOpen: root.hasSubmenu && root.menu.activeEntry === root

  // Hovering an entry makes it its menu's active one: opens its own submenu,
  // if any, and closes whichever other one was open.
  HoverHandler {
    onHoveredChanged: {
      if (hovered && !root.modelData.isSeparator) root.menu.activeEntry = root
    }
  }

  // Created the first time it opens, and kept.
  Loader {
    id: submenuLoader
  }

  onSubmenuOpenChanged: {
    if (root.submenuOpen && !submenuLoader.item) {
      submenuLoader.setSource("TraySubmenu.qml", { entry: root, rootMenu: root.rootMenu })
    }
  }

  // Emitted (with no arguments) after this entry's own action has been
  // triggered, so the parent can close the popup without needing to
  // reference `modelData` itself at the call site (which would resolve
  // to an ancestor's own `property var modelData` instead of this row's).
  signal activated()

  // Column (used by PopupMenu) lays out and sizes itself from children's
  // `width`/`height`, not `implicitWidth`/`implicitHeight` - bind both so
  // this row actually takes up space. A separator, which has no label of its
  // own to size it, spans the whole menu instead (as wide as its widest
  // entry), rather than being a short stub at its left.
  anchors.left: modelData.isSeparator ? parent?.left : undefined
  anchors.right: modelData.isSeparator ? parent?.right : undefined
  width: modelData.isSeparator ? 0 : option.width
  height: modelData.isSeparator ? 11 : option.height
  implicitWidth: width
  implicitHeight: height

  // A soft hairline, inset from the menu's rounded sides, with rounded ends.
  Rectangle {
    visible: root.modelData.isSeparator
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    height: 1
    radius: 0.5
    color: Theme.separatorColor
    opacity: 0.5
  }

  PowerMenuOption {
    id: option
    visible: !root.modelData.isSeparator
    enabled: root.modelData.enabled
    // Lit while its submenu is open.
    active: root.submenuOpen
    label: root.modelData.text + (root.hasSubmenu ? "  ›" : "")
    onClicked: {
      if (root.hasSubmenu) {
        root.menu.activeEntry = root
        return
      }
      root.modelData.triggered()
      root.activated()
    }
  }
}
