import QtQuick
import Quickshell
import qs.components

// The submenu of a tray menu entry (see TrayMenuItem): beside its menu,
// level with the entry, shown while that entry is its menu's active one. In
// a file of its own, loaded by URL, since its entries can have submenus too.
PopupMenu {
  id: root

  // The entry it opens from.
  required property Item entry
  // The top-level menu, which an entry activated anywhere below closes.
  required property Item rootMenu

  anchorItem: root.entry
  parentMenu: root.entry.menu
  // Its top-level menu already closes on a click outside, taking it along.
  grabFocus: false
  visible: root.parentMenu.visible && root.parentMenu.activeEntry === root.entry

  QsMenuOpener {
    id: opener
    menu: root.entry.modelData
  }

  Repeater {
    model: opener.children

    TrayMenuItem {
      menu: root
      rootMenu: root.rootMenu
      onActivated: root.rootMenu.visible = false
    }
  }
}
