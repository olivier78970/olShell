import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// The clock's popup: a tab bar over the page of the current tab (agenda,
// performance), toggled from the clock widget on whichever screen it's
// clicked from (ClockPanelState.anchorItem) - a single panel shared by every
// screen's bar, rather than one popup per bar. While open, its frame is
// drawn inside that screen's bar (see config/BarSlots.qml), which also
// closes it on a click outside.
//
// To add a feature, append an entry to `tabs` and a matching page inside
// the StackLayout below (same order).
Item {
  id: root

  readonly property var tabs: [
    { label: I18n.tr("clock.tab.agenda"), icon: "󰃭" },
    { label: I18n.tr("clock.tab.performance"), icon: "󰓅" }
  ]

  // The screen to show on: wherever the open clock widget lives. A Wayland
  // client can't ask an arbitrary screen "where is this Item", only the
  // window an item actually belongs to - so this asks that window instead.
  readonly property var targetScreen: {
    const item = ClockPanelState.anchorItem
    const win = item ? item.QsWindow.window : null
    return win ? win.screen : null
  }

  // The bar slot the frame is drawn in while open.
  readonly property Item hostSlot: ClockPanelState.visible ? BarSlots.slotFor(root.targetScreen) : null

  Connections {
    target: root.hostSlot

    function onDismissed() {
      ClockPanelState.visible = false
    }
  }

  // Where the frame waits while closed.
  Item {
    id: home
    visible: false
  }

  Rectangle {
    id: frame

    parent: root.hostSlot ?? home

    readonly property real inset: 8
    // As wide as the pages want to be, but never narrower than the tab
    // bar needs to show every tab, so adding tabs widens the popup
    // instead of cutting them off.
    readonly property real minWidth: 520

    width: Math.max(frame.minWidth, tabBar.implicitWidth) + frame.inset * 2
    height: tabBar.implicitHeight + 12 + pages.height + frame.inset * 2
    radius: Theme.radiusFor(height)
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth

    TabBar {
      id: tabBar
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: frame.inset
      model: root.tabs
    }

    StackLayout {
      id: pages
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: tabBar.bottom
      anchors.leftMargin: frame.inset
      anchors.rightMargin: frame.inset
      anchors.topMargin: 12
      currentIndex: tabBar.currentIndex
      // As tall as the page being shown, not as the tallest one, so the
      // popup adapts to the tab's content.
      height: children[currentIndex] ? children[currentIndex].implicitHeight : 0

      AgendaTab {}

      PerformanceTab {}
    }
  }
}
