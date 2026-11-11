import QtQuick
import qs.config

// The line between groups of entries in a bar widget's menu or popup
// (PopupMenu, HoverPopup), the same in every one: a soft hairline across the
// whole width of whatever holds it, from one side of the menu's content to
// the other.
Item {
  anchors.left: parent?.left
  anchors.right: parent?.right
  height: 11

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 1
    color: Theme.separatorColor
    opacity: 0.5
  }
}
