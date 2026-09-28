import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The clock's popup: a tab bar over the page of the current tab (agenda,
// performance, media, weather, clocks), toggled from the clock widget on
// whichever screen it's clicked from (ClockPanelState.anchorItem) - a
// single panel shared by every screen's bar, rather than one popup per bar.
// Placed like the other panels (Settings.clockPlacement, see ModalPanel's
// `placement`): against the bar by default, on the screen of the clock
// clicked. Tab / Shift+Tab switch tabs, Escape or a click outside closes.
//
// To add a feature, append an entry to `tabs` and a matching page inside
// the StackLayout below (same order).
ModalPanel {
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

  // The room around the tab bar and the pages.
  readonly property real inset: 8
  // As wide as the pages want to be, but never narrower than the tab bar
  // needs to show every tab, so adding tabs widens the popup instead of
  // cutting them off.
  readonly property real minWidth: 520

  // Sized to the tab bar and the page shown (the screen still caps it).
  maxPanelWidth: Math.ceil(Math.max(root.minWidth, tabBar.implicitWidth) + root.inset * 2)
  maxPanelHeight: Math.ceil((tabBar.visible ? tabBar.implicitHeight + 12 : 0) + pages.height + root.inset * 2)
  placement: Settings.clockPlacement
  anchorItem: ClockPanelState.anchorItem

  open: ClockPanelState.visible
  onCloseRequested: ClockPanelState.visible = false

  IpcHandler {
    target: "clock"

    // Opens or closes the panel (on the focused screen, with no clock to
    // open from).
    function toggle(): void {
      ClockPanelState.toggle(null)
    }
  }

  onKeyPressed: event => {
    if (root.shownTabs.length < 2) return
    const count = root.shownTabs.length
    if (event.key === Qt.Key_Tab) {
      tabBar.currentIndex = (tabBar.currentIndex + 1) % count
      event.accepted = true
    } else if (event.key === Qt.Key_Backtab) {
      tabBar.currentIndex = (tabBar.currentIndex + count - 1) % count
      event.accepted = true
    }
  }

  // Only with more than one tab to choose from.
  TabBar {
    id: tabBar
    visible: root.shownTabs.length > 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.inset
    model: root.shownTabs
  }

  StackLayout {
    id: pages
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: tabBar.visible ? tabBar.bottom : parent.top
    anchors.leftMargin: root.inset
    anchors.rightMargin: root.inset
    anchors.topMargin: tabBar.visible ? 12 : root.inset
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
