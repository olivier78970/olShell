import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Pilot: PopupMenu.qml's visuals and API, but backed by two layer-shell
// PanelWindows (a backdrop and a frame, see ModalPanel.qml) instead of an
// xdg-popup. PopupWindow's surface type isn't matched by Hyprland's
// namespace-based blur layer rule (see services/Blur.qml's own comment),
// which is the whole point of this version - the frame sits on Quickshell's
// default namespace, so it blurs like everything else.
//
// Single-monitor only for now: with no explicit `screen` to inherit (a
// Wayland client can't ask where its own items are on screen, see the
// margins math below), both windows land on the default/primary screen.
Item {
  id: root

  default property alias content: column.data
  property Item anchorItem
  // Right-align below the widget by default (for widgets in the bar's
  // right area); set true for widgets in the left area to left-align.
  property bool alignLeft: false
  // Center below the widget instead (overrides alignLeft).
  property bool alignCenter: false
  visible: false
  // True while the pointer is over the popup itself.
  readonly property bool containsMouse: hover.hovered

  // The bar's own edge, where the widget's pill is: below it normally, but
  // above it when the bar is at the bottom of the screen, so the popup
  // always opens toward the middle of the screen instead of off the edge.
  readonly property bool barAtTop: Theme.barPosition !== "bottom"

  // The bar's own on-screen origin. A Wayland client can't ask the
  // compositor for its absolute position, so this reconstructs it from the
  // same values Bar.qml itself anchors with; once revealed (required for a
  // popup to be open to begin with), auto-hide and not converge on the same
  // resting geometry, so a single formula covers both.
  function barOriginX() {
    return Theme.barAutoHide ? 0 : Theme.barMarginLeft
  }

  function barOriginY() {
    if (Theme.barAutoHide) return 0
    return root.barAtTop ? Theme.barMarginTop : frameWindow.screen.height - Theme.barMarginBottom - Theme.barHeight
  }

  // anchorItem's on-screen position: its position within its own window
  // (the bar's), plus that window's own on-screen origin above.
  readonly property point anchorPos: root.anchorItem && frameWindow.screen
    ? Qt.point(root.anchorItem.mapToItem(null, 0, 0).x + root.barOriginX(), root.anchorItem.mapToItem(null, 0, 0).y + root.barOriginY())
    : Qt.point(0, 0)

  // Where the frame's top-left goes, in screen coordinates - the same
  // anchor/gravity/margins PopupMenu.qml gives the xdg-popup positioner,
  // worked out by hand instead.
  function frameX() {
    if (!root.anchorItem) return 0
    if (root.alignCenter) return root.anchorPos.x + root.anchorItem.width / 2 - surface.width / 2
    return root.alignLeft ? root.anchorPos.x : root.anchorPos.x + root.anchorItem.width - surface.width
  }

  function frameY() {
    if (!root.anchorItem) return 0
    // Widgets are vertically centered within their (taller) pill; start the
    // popup flush with the pill's edge instead of the widget's, then
    // overlap the border width instead of doubling up with the pill's.
    const pillGap = (Theme.pillHeight() - root.anchorItem.height) / 2
    return root.barAtTop
      ? root.anchorPos.y + root.anchorItem.height + pillGap - Theme.borderWidth
      : root.anchorPos.y - pillGap + Theme.borderWidth - surface.height
  }

  // Invisible full-screen surface, just to catch a click outside the frame
  // and close the popup - not blurred (see frameWindow below), and not
  // dimmed either, unlike ModalPanel's: this is a lightweight dropdown; the
  // rest of the screen only darkens for an actual modal panel.
  PanelWindow {
    id: backdrop

    visible: root.visible

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
      onClicked: root.visible = false
    }
  }

  // The actual popup, its own layer-shell surface on Quickshell's default
  // namespace (like the bar, pills, panels and OSDs, see services/Blur.qml).
  PanelWindow {
    id: frameWindow

    visible: root.visible

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
      top: true
      left: true
    }
    margins.left: root.frameX()
    margins.top: root.frameY()
    implicitWidth: surface.width
    implicitHeight: surface.height

    color: "transparent"
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: surface
      width: column.implicitWidth + 16
      height: column.implicitHeight + 16
      clip: true

      // No compositor blur reaches an xdg-popup (see this file's own header
      // comment), so Theme.blur fakes it the way the lock screen does: a
      // blurred copy of the wallpaper image, under the tinted, bordered
      // rectangle below (which has to be the last child, drawn on top of
      // this, or its own border would just get painted over).
      Image {
        id: wallpaper
        anchors.fill: parent
        visible: false
        source: Theme.blur && ThemeState.wallpaper.length > 0 ? "file://" + ThemeState.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      MultiEffect {
        anchors.fill: parent
        visible: Theme.blur && wallpaper.status === Image.Ready
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
      }

      Rectangle {
        anchors.fill: parent
        radius: Theme.radiusFor(height)
        color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
        border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
        border.width: Theme.borderWidth
      }

      HoverHandler {
        id: hover
      }

      Column {
        id: column
        anchors.centerIn: parent
        spacing: 6
      }
    }
  }
}
