import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config

// The clock's popup: a tab bar over the page of the current tab (agenda,
// performance), toggled from the clock widget on whichever screen it's
// clicked from (ClockPanelState.anchorItem) - a single top-level panel
// shared by every screen's bar, rather than one popup per bar.
//
// The backdrop and the frame are two separate layer-shell surfaces (see
// frameWindow below) so a blur layer rule can target just the frame - see
// NotificationCenter.qml, which this mirrors. Being on Quickshell's default
// namespace (unlike PopupMenu's xdg-popups, see services/Blur.qml), the
// frame gets real compositor blur instead of PopupMenu's fake wallpaper one.
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

  readonly property bool barAtTop: Theme.barPosition !== "bottom"

  // The bar's own on-screen origin, reconstructed the same way Bar.qml
  // itself anchors (a Wayland client can't ask the compositor for its
  // absolute position either); auto-hide and not converge on the same
  // resting geometry, so a single formula covers both.
  function barOriginX() {
    return Theme.barAutoHide ? 0 : Theme.barMarginLeft
  }

  function barOriginY() {
    if (Theme.barAutoHide) return 0
    return root.barAtTop ? Theme.barMarginTop : root.targetScreen.height - Theme.barMarginBottom - Theme.barHeight
  }

  // anchorItem's on-screen position: its position within its own window
  // (that screen's bar), plus that window's own on-screen origin above.
  readonly property point anchorPos: {
    const item = ClockPanelState.anchorItem
    if (!item || !root.targetScreen) return Qt.point(0, 0)
    const p = item.mapToItem(null, 0, 0)
    return Qt.point(p.x + root.barOriginX(), p.y + root.barOriginY())
  }

  // Where the frame's top-left goes, in screen coordinates: centered below
  // (or above, on a bottom bar) the clock widget.
  function frameX() {
    const item = ClockPanelState.anchorItem
    if (!item) return 0
    return root.anchorPos.x + item.width / 2 - frame.width / 2
  }

  function frameY() {
    const item = ClockPanelState.anchorItem
    if (!item) return 0
    // Widgets are vertically centered within their (taller) pill; start the
    // popup flush with the pill's edge instead of the widget's, then
    // overlap the border width instead of doubling up with the pill's.
    const pillGap = (Theme.pillHeight() - item.height) / 2
    return root.barAtTop
      ? root.anchorPos.y + item.height + pillGap - Theme.borderWidth
      : root.anchorPos.y - pillGap + Theme.borderWidth - frame.height
  }

  // Invisible full-screen surface, just to catch a click outside the frame
  // and close the panel - not blurred (see frameWindow below) or dimmed
  // either, unlike a modal panel's: this is a lightweight dropdown.
  PanelWindow {
    id: backdrop

    visible: ClockPanelState.visible && root.targetScreen !== null
    screen: root.targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:backdrop"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: ClockPanelState.visible = false
    }
  }

  // The actual popup, its own layer-shell surface on Quickshell's default
  // namespace (like the bar, pills, panels and OSDs, see services/Blur.qml).
  PanelWindow {
    id: frameWindow

    visible: backdrop.visible
    screen: root.targetScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
      top: true
      left: true
    }
    margins.left: root.frameX()
    margins.top: root.frameY()
    implicitWidth: frame.width
    implicitHeight: frame.height

    color: "transparent"
  
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      id: frame

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
}
