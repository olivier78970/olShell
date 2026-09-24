import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config

// Screen-centered modal panel: a dimmed full-screen backdrop and a framed
// panel that takes exclusive keyboard focus. Children go inside the frame.
// Every key, Escape included, is passed on through `keyPressed` first, so the
// owner can use it for something of its own (closing a dropdown's list, say);
// a click outside the panel always emits `closeRequested`, and so does
// Escape, unless the owner's `keyPressed` accepted it.
//
// The owner controls visibility (bind `visible`) and reacts to the signals;
// this component keeps no state of its own about being open.
//
// The backdrop and the frame are two separate layer-shell surfaces (see
// frameWindow below) so a blur layer rule can target just the frame.
//
// With `attached`, the panel opens against the bar instead, like the clock
// panel: horizontally centered on the screen, flush below (or above, on a
// bottom bar) `anchorItem`'s pill, on its screen - or, without an
// anchorItem (when opened by IPC), flush with the focused screen's bar. Nothing is
// dimmed then: the backdrop only catches the click outside.
PanelWindow {
  id: root

  // Design size of the frame; it shrinks to fit smaller screens.
  property real maxPanelWidth: 800
  property real maxPanelHeight: 600
  // Opacity of the frame's own fill (never its content, see contentHolder
  // below, or its border, which follows Theme.widgetOpacity directly).
  property real panelOpacity: Theme.widgetOpacity
  // Whether the frame is drawn; without it only the children show, over the
  // dimmed backdrop.
  property bool framed: true
  // Gets keyboard focus each time the panel opens (default: the frame).
  property Item focusTarget: frame
  // Opens against the bar rather than centered on the screen (see above).
  property bool attached: false
  // The bar widget an attached panel opens from, if any.
  property Item anchorItem: null

  // The frame, e.g. to size content from it.
  readonly property Item panel: frame
  default property alias content: contentHolder.data

  signal closeRequested()
  // Emitted each time the panel becomes visible.
  signal opened()
  // A key that neither Escape nor the focused item used; set
  // `event.accepted = true` to consume it.
  signal keyPressed(var event)

  WlrLayershell.layer: WlrLayer.Overlay
  // A distinct namespace from frameWindow's default one (shared with the
  // bar, pills, popups and OSDs, all of which do want to blur) so a blur
  // layer rule can leave the backdrop out - see frameWindow below.
  WlrLayershell.namespace: "quickshell:backdrop"

  // Fills the whole screen (rather than just sizing to its content) so
  // the dimmed backdrop below covers everything and clicks outside the
  // panel are swallowed instead of reaching windows behind it.
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  color: "transparent"
  aboveWindows: true
  // No keyboard focus of its own: frameWindow below takes it instead.
  focusable: false
  // Ignore the bar's reserved exclusive zone so the backdrop covers the
  // whole screen, including the strip behind the top bar.
  exclusionMode: ExclusionMode.Ignore

  onVisibleChanged: {
    if (root.visible) root.opened()
  }

  readonly property bool barAtTop: Theme.barPosition !== "bottom"
  // What the bar takes up at its edge of the screen, margins included.
  readonly property real barZone: Theme.barMarginTop + Theme.barHeight + Theme.barMarginBottom

  // An attached panel's screen: anchorItem's own (asked of the window it
  // belongs to, the only thing a Wayland client can know about where an
  // item is), or else the focused one.
  readonly property var targetScreen: {
    const win = root.anchorItem ? root.anchorItem.QsWindow.window : null
    if (win) return win.screen
    return Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
  }

  // Only attached panels move; the others keep the default screen.
  Binding {
    target: root
    property: "screen"
    value: root.targetScreen
    when: root.attached && root.targetScreen !== null
  }

  // anchorItem's on-screen position, reconstructed as ClockPanel does:
  // its position within its bar's window, plus that window's own origin.
  readonly property point anchorPos: {
    const item = root.anchorItem
    if (!item) return Qt.point(0, 0)
    const p = item.mapToItem(null, 0, 0)
    const originX = Theme.barAutoHide ? 0 : Theme.barMarginLeft
    const originY = Theme.barAutoHide ? 0
      : (root.barAtTop ? Theme.barMarginTop : root.height - Theme.barMarginBottom - Theme.barHeight)
    return Qt.point(p.x + originX, p.y + originY)
  }

  // Where an attached frame's top-left goes, in screen coordinates.
  // Always horizontally centered on the screen, like every panel attached
  // to the bar; anchorItem only decides the screen and the vertical edge.
  function attachedX() {
    return (root.width - frame.width) / 2
  }

  function attachedY() {
    const item = root.anchorItem
    if (!item) {
      // Against the bar, Theme.panelOffset() away from it.
      return root.barAtTop ? root.barZone - Theme.barMarginBottom + Theme.panelOffset()
        : root.height - root.barZone + Theme.barMarginTop - Theme.panelOffset() - frame.height
    }
    // Against the widget's pill, as the clock panel is (widgets sit
    // vertically centered in their taller pill), Theme.panelOffset() away.
    const pillGap = (Theme.pillHeight() - item.height) / 2
    return root.barAtTop
      ? root.anchorPos.y + item.height + pillGap + Theme.panelOffset()
      : root.anchorPos.y - pillGap - Theme.panelOffset() - frame.height
  }

  // Dimmed backdrop covering the whole screen; clicking it closes the
  // panel, like clicking outside any other modal dialog. A click actually
  // on the frame never reaches this MouseArea to begin with - it's a
  // separate, topmost surface - but the bounds check is kept as a safety
  // net against stacking surprises.
  MouseArea {
    anchors.fill: parent
    onClicked: mouse => {
      const insidePanel = mouse.x >= frameWindow.margins.left && mouse.x <= frameWindow.margins.left + frame.width
        && mouse.y >= frameWindow.margins.top && mouse.y <= frameWindow.margins.top + frame.height
      if (!insidePanel) root.closeRequested()
    }

    Rectangle {
      visible: !root.attached
      anchors.fill: parent
      color: "black"
      opacity: 0.4
    }
  }

  // The actual dialog, its own layer-shell surface on Quickshell's default
  // namespace (like the bar, pills, popups and OSDs, see services/Blur.qml)
  // rather than root's: Hyprland blurs whatever's behind a whole surface,
  // and the frame used to share the backdrop's, which meant the dim blurred
  // too instead of staying sharp. Centered with explicit margins (rather
  // than left unanchored) so its on-screen geometry is known here, for the
  // bounds check above.
  PanelWindow {
    id: frameWindow

    // Only once the backdrop's own window is actually up, not just when
    // it's asked to be: Hyprland stacks surfaces on the same layer in
    // creation order, so a frame created first would end up under the
    // backdrop, which would then swallow every click meant for it.
    visible: root.backingWindowVisible
    screen: root.screen

    WlrLayershell.layer: WlrLayer.Overlay
    // Takes the keyboard when it opens (Hyprland focuses a newly mapped
    // OnDemand surface). Not Exclusive: Hyprland then only sends pointer
    // input to this surface, so a click outside would never reach the
    // backdrop and the panel couldn't be closed that way.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
      top: true
      left: true
    }
    margins.left: root.attached ? root.attachedX() : (root.width - frame.width) / 2
    margins.top: root.attached ? root.attachedY() : (root.height - frame.height) / 2
    implicitWidth: frame.width
    implicitHeight: frame.height

    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    // Grabbed here, from this window's own visibility, rather than root's:
    // frameWindow's `visible` only mirrors root's a binding tick later, so
    // requesting focus from root's own visibleChanged could fire before
    // this window (and its surface) actually exists yet to grab it.
    onVisibleChanged: {
      if (frameWindow.visible) root.focusTarget.forceActiveFocus()
    }

    Rectangle {
      id: frame
      // An attached frame stays within the bar's span, and leaves room for
      // the bar itself.
      width: Math.min(root.maxPanelWidth, root.attached ? root.width - Theme.barMarginLeft - Theme.barMarginRight : root.width * 0.9)
      height: Math.min(root.maxPanelHeight, root.attached ? root.height - root.barZone - 20 : root.height * 0.9)
      radius: Theme.radiusFor(height)
      color: root.framed ? Theme.fade(Theme.pillColor, root.panelOpacity) : "transparent"
      // The border follows the real widget opacity (and Theme.borderOpaque),
      // not `panelOpacity`: a panel like the settings one can clamp its own
      // fill higher to stay readable, but that readability floor isn't a
      // reason to also mute how much the border itself fades.
      border.color: root.framed ? Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity) : "transparent"
      border.width: root.framed ? Theme.borderWidth : 0
      focus: true

      Keys.onPressed: event => {
        // Escape goes to the owner first, so it can use it for something of
        // its own (closing a dropdown's list, say) instead of the panel; it
        // only closes the panel if that leaves it unaccepted.
        root.keyPressed(event)
        if (event.key === Qt.Key_Escape && !event.accepted) {
          root.closeRequested()
          event.accepted = true
        }
      }

      // Content never fades with the widget opacity, same as a bar pill's:
      // only the fill and border do, so text and icons stay fully readable.
      // A separate item from `frame` so it doesn't inherit the fill/border's
      // own opacity/color handling.
      Item {
        id: contentHolder
        anchors.fill: parent
      }
    }
  }
}
