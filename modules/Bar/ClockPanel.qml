import QtQuick
import QtQuick.Layouts
import qs.config

// Content of the clock's popup: a tab bar over the page of the current tab
// (agenda, performance).
//
// To add a feature, append an entry to `tabs` and a matching page inside
// the StackLayout below (same order).
Item {
  id: root

  readonly property var tabs: [
    { label: "Agenda", icon: "󰃭" },
    { label: "Performances", icon: "󰓅" }
  ]

  // As wide as the pages want to be, but never narrower than the tab bar
  // needs to show every tab, so adding tabs widens the popup instead of
  // cutting them off.
  readonly property real minWidth: 520

  // Column (used by PopupMenu) sizes from width/height, not the implicit ones.
  implicitWidth: Math.max(root.minWidth, tabBar.implicitWidth)
  implicitHeight: tabBar.implicitHeight + 12 + pages.height
  width: implicitWidth
  height: implicitHeight

  TabBar {
    id: tabBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    model: root.tabs
  }

  StackLayout {
    id: pages
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: tabBar.bottom
    anchors.topMargin: 12
    currentIndex: tabBar.currentIndex
    // As tall as the page being shown, not as the tallest one, so the popup
    // adapts to the tab's content.
    height: children[currentIndex] ? children[currentIndex].implicitHeight : 0

    AgendaTab {}

    PerformanceTab {}
  }
}
