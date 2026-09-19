import QtQuick
import qs.config

// One row in a tray item's context menu: a separator line, or a
// PowerMenuOption-styled clickable entry.
//
// Entries with children (submenus) are shown with a "›" marker but are
// not yet openable. Two approaches were tried and both fail in this
// environment: (1) a second custom PopupWindow anchored to an item that
// lives inside another PopupWindow's content reports the right visible
// state and size but never actually maps as a surface (renders nothing,
// anywhere); (2) the platform-native QsMenuEntry.display() call requires
// a real QWindow, but anything hosted inside a PanelWindow only exposes
// Quickshell's own ProxiedWindow wrapper, which display() rejects with
// "must be called with a window". Revisit if a future Quickshell version
// changes either of those.
Item {
  id: root

  required property var modelData

  // Emitted (with no arguments) after this entry's own action has been
  // triggered, so the parent can close the popup without needing to
  // reference `modelData` itself at the call site (which would resolve
  // to an ancestor's own `property var modelData` instead of this row's).
  signal activated()

  // Column (used by PopupMenu) lays out and sizes itself from children's
  // `width`/`height`, not `implicitWidth`/`implicitHeight` - bind both so
  // this row actually takes up space.
  width: option.width
  height: modelData.isSeparator ? 9 : option.height
  implicitWidth: width
  implicitHeight: height

  Rectangle {
    visible: root.modelData.isSeparator
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 1
    color: Theme.separatorColor
  }

  PowerMenuOption {
    id: option
    visible: !root.modelData.isSeparator
    enabled: root.modelData.enabled && !root.modelData.hasChildren
    label: root.modelData.text + (root.modelData.hasChildren ? "  ›" : "")
    onClicked: {
      root.modelData.triggered()
      root.activated()
    }
  }
}
