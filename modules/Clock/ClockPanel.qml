import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config

// The clock's popup: a tab bar over the page of the current tab (agenda,
// performance, media, weather, clocks), toggled from the clock widget on whichever screen it's
// clicked from (ClockPanelState.anchorItem) - a single panel shared by every
// screen's bar, rather than one popup per bar. While open, its frame is
// drawn inside that screen's bar (see config/BarSlots.qml), which also
// closes it on a click outside.
//
// To add a feature, append an entry to `tabs` and a matching page inside
// the StackLayout below (same order).
Item {
  id: root

  // Every tab, in the order of the pages below, with the setting showing it.
  readonly property var tabs: [
    { label: I18n.tr("clock.tab.agenda"), icon: "󰃭", shown: Settings.clockShowAgenda },
    { label: I18n.tr("clock.tab.performance"), icon: "󰓅", shown: Settings.clockShowPerformance },
    { label: I18n.tr("clock.tab.media"), icon: "󰝚", shown: Settings.clockShowMedia },
    { label: I18n.tr("clock.tab.weather"), icon: "󰖕", shown: Settings.clockShowWeather },
    { label: I18n.tr("clock.tab.world"), icon: "󰥔", shown: Settings.clockShowWorld }
  ]
  // The tabs shown (the settings' Panels > Clock tab); the agenda with none,
  // so the clock always opens something.
  readonly property var shownTabs: {
    const shown = root.tabs.filter(tab => tab.shown)
    return shown.length > 0 ? shown : [root.tabs[0]]
  }
  // Back to the first tab when the one picked was turned off.
  onShownTabsChanged: if (tabBar.currentIndex >= root.shownTabs.length) tabBar.currentIndex = 0
  // The page of the tab picked, among all of them.
  readonly property int page: root.tabs.indexOf(root.shownTabs[Math.min(tabBar.currentIndex, root.shownTabs.length - 1)])

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

    // Whole pixels, so its sides sit on pixel edges, as the curved joins
    // beside them do (see the bar's panelSlot).
    width: Math.ceil(Math.max(frame.minWidth, tabBar.implicitWidth) + frame.inset * 2)
    height: Math.ceil((tabBar.visible ? tabBar.implicitHeight + 12 : 0) + pages.height + frame.inset * 2)
    radius: Theme.radiusFor(height)
    topLeftRadius: Theme.attachedCorner(radius, true)
    topRightRadius: Theme.attachedCorner(radius, true)
    bottomLeftRadius: Theme.attachedCorner(radius, false)
    bottomRightRadius: Theme.attachedCorner(radius, false)
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth

    // Curves it out of the bar when flush against it.
    BarFillets {
      color: frame.color
      borderColor: frame.border.color
    }

    // Only with more than one tab to choose from.
    TabBar {
      id: tabBar
      visible: root.shownTabs.length > 1
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: frame.inset
      model: root.shownTabs
    }

    StackLayout {
      id: pages
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: tabBar.visible ? tabBar.bottom : parent.top
      anchors.leftMargin: frame.inset
      anchors.rightMargin: frame.inset
      anchors.topMargin: tabBar.visible ? 12 : frame.inset
      currentIndex: root.page
      // As tall as the page being shown, not as the tallest one, so the
      // popup adapts to the tab's content.
      height: children[currentIndex] ? children[currentIndex].implicitHeight : 0

      AgendaTab {}

      PerformanceTab {}

      MediaTab {}

      WeatherTab {}

      WorldClockTab {}
    }
  }
}
