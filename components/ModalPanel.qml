import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config

// Screen-centered modal panel: a full-screen backdrop (dimmed, with `dimmed`)
// and a framed panel that takes exclusive keyboard focus. Children go inside the frame.
// Every key, Escape included, is passed on through `keyPressed` first, so the
// owner can use it for something of its own (closing a dropdown's list, say);
// a click outside the panel always emits `closeRequested`, and so does
// Escape, unless the owner's `keyPressed` accepted it.
//
// The owner controls visibility (bind `open`) and reacts to the signals;
// this component keeps no state of its own about being open.
//
// The backdrop and the frame are two separate layer-shell surfaces (see
// frameWindow below) so a blur layer rule can target just the frame.
//
// With a `placement` on the bar ("bar-left", "bar-center" or "bar-right";
// `attached` is then true), the panel opens against the bar instead, like
// the clock panel, at that end or in the middle of it (the left end is the
// top one of a side bar): on `anchorItem`'s screen - or, without an anchorItem (when opened
// by IPC), the focused one - with nothing dimmed. Neither of these windows
// shows then: the frame is drawn inside that screen's bar (see
// config/BarSlots.qml), which also takes care of the click outside.
PanelWindow {
  id: root

  // Design size of the frame; it shrinks to fit smaller screens.
  property real maxPanelWidth: 800
  property real maxPanelHeight: 600
  // The height the frame is placed for when it's shorter: a frame whose
  // height follows its content (the launcher's) keeps its top where a frame
  // this tall would have it, rather than moving as it grows and shrinks. 0
  // centers it on its own height.
  property real placementHeight: 0
  // Opacity of the frame's own fill (never its content, see contentHolder
  // below, or its border, which follows Theme.widgetOpacity directly).
  property real panelOpacity: Theme.widgetOpacity
  // Whether the frame is drawn; without it only the children show, over the
  // backdrop.
  property bool framed: true
  // Whether the rest of the screen is darkened while it's open (none of the
  // shell's panels is now); the backdrop still catches a click outside
  // either way.
  property bool dimmed: false
  // How dark it gets then (the opacity of the black laid over the screen).
  property real dimOpacity: 0.4
  // Gets keyboard focus each time the panel opens (default: the frame).
  property Item focusTarget: frame
  // Whether the panel is open; the owner binds it (not `visible`, which an
  // attached panel keeps false).
  property bool open: false
  // Where the panel opens: "center" (of the screen), against its left or
  // right edge halfway down ("center-left", "center-right", as far from that
  // edge as the bar is from it), against the bar at its
  // left end, in its middle or at its right end ("bar-left", "bar-center",
  // "bar-right"), or the same against the screen's edge opposite the bar
  // ("opposite-left", "opposite-center", "opposite-right"), as far from it
  // and from the sides as the bar is from its own; one of
  // Settings.panelPlacements.
  property string placement: "center"
  // Whether it opens against the bar rather than centered on the screen
  // (see above).
  readonly property bool attached: root.placement.startsWith("bar-")
  // Where along the bar an attached panel goes: "left", "center" or "right".
  readonly property string barAlign: root.attached ? root.placement.slice(4) : "center"
  // Whether it opens against the edge opposite the bar.
  readonly property bool opposite: root.placement.startsWith("opposite-")
  // The bar widget an attached panel opens from, if any.
  property Item anchorItem: null

  // The frame, e.g. to size content from it.
  readonly property Item panel: frame
  default property alias content: contentHolder.data

  signal closeRequested()
  // Emitted each time the panel opens.
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

  // How far it has come in, from 0 (gone) to 1 (all there), easing toward
  // `open`: an attached panel slides out from under the bar, the others grow
  // a little as they fade in (see frame), and the reverse as it closes.
  // Driven by an animation of its own rather than a Behavior, which doesn't
  // animate the first change of a panel built already open (see below).
  property real progress: 0
  // Whether it's drawn: while open, and while it's still going away.
  readonly property bool shown: root.open || root.progress > 0

  NumberAnimation {
    id: progressAnimation
    target: root
    property: "progress"
    duration: Theme.animationDuration
    easing.type: Easing.OutCubic
  }

  // Eases `progress` to 1 while open, to 0 otherwise.
  function animateProgress() {
    progressAnimation.stop()
    progressAnimation.to = root.open ? 1 : 0
    progressAnimation.start()
  }

  visible: root.shown && !root.attached

  onOpenChanged: {
    if (root.open) root.opened()
    root.animateProgress()
  }

  // A panel only built when it opens (see the *Module.qml files, which load
  // it with a LazyLoader, kept a moment longer so it can animate away) is open
  // from the start, so `open` and `hostSlot` never change for it: it opens
  // here instead.
  Component.onCompleted: {
    root.animateProgress()
    if (!root.open) return
    root.opened()
    if (root.hostSlot) Qt.callLater(() => root.focusTarget.forceActiveFocus())
  }

  // For an attached panel, where its body is drawn: back toward the bar by the
  // part not out yet.
  readonly property point slide: {
    const hidden = root.attached ? 1 - root.progress : 0
    if (Theme.barVertical) return Qt.point((Theme.barPosition === "left" ? -1 : 1) * hidden * frame.width, 0)
    return Qt.point(0, (Theme.barPosition === "bottom" ? 1 : -1) * hidden * frame.height)
  }

  // What the bar takes up across its edge of the screen, margins included.
  readonly property real barZone: Theme.barZone()

  // An attached panel's screen: anchorItem's own (asked of the window it
  // belongs to, the only thing a Wayland client can know about where an
  // item is), or else the focused one.
  readonly property var targetScreen: {
    const win = root.anchorItem ? root.anchorItem.QsWindow.window : null
    if (win) return win.screen
    return Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
  }

  // The bar slot an open attached panel's frame is drawn in, if any.
  readonly property Item hostSlot: root.shown && root.attached ? BarSlots.slotFor(root.targetScreen) : null
  // The room the frame sizes itself to: the backdrop's, or the target
  // screen's for an attached panel (whose backdrop never shows).
  readonly property real areaWidth: root.attached && root.targetScreen ? root.targetScreen.width : root.width
  readonly property real areaHeight: root.attached && root.targetScreen ? root.targetScreen.height : root.height

  // Takes the keyboard once in the bar (its window gets it from the bar's
  // focus grab), a tick later so the frame has actually moved there; by
  // then a panel closed at once may already be gone.
  onHostSlotChanged: {
    if (root.hostSlot) Qt.callLater(() => root?.focusTarget?.forceActiveFocus())
  }

  Connections {
    target: root.hostSlot

    function onDismissed() {
      root.closeRequested()
    }
  }

  // Backdrop covering the whole screen (dimmed with `dimmed`); clicking it closes the
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
      visible: root.dimmed
      anchors.fill: parent
      color: "black"
      opacity: root.dimOpacity
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
    // Against the edge opposite the bar, as far from it as the bar is from
    // its own edge, at the place along it the placement names (its top for
    // "left" beside a side bar); or halfway down, centered or against a side
    // (beside a bar on that side, as far from it as windows are).
    margins.left: {
      if (root.opposite && Theme.barVertical) {
        return Theme.barPosition === "left" ? root.width - frame.width - Theme.barMarginLeft : Theme.barMarginRight
      }
      const align = root.opposite ? root.placement.slice(9)
        : root.placement === "center-left" ? "left"
        : root.placement === "center-right" ? "right"
        : "center"
      if (align === "left") return Theme.barPosition === "left" ? root.barZone : Theme.barMarginLeft
      if (align === "right") return root.width - frame.width - (Theme.barPosition === "right" ? root.barZone : Theme.barMarginRight)
      return (root.width - frame.width) / 2
    }
    margins.top: {
      if (root.opposite && Theme.barVertical) {
        const align = root.placement.slice(9)
        if (align === "left") return Theme.barMarginTop
        if (align === "right") return root.height - frame.height - Theme.barMarginBottom
        return (root.height - frame.height) / 2
      }
      if (!root.opposite) return (root.height - Math.max(frame.height, Math.min(root.placementHeight, root.areaHeight * 0.9))) / 2
      return Theme.barPosition === "bottom" ? Theme.barMarginBottom : root.height - frame.height - Theme.barMarginTop
    }
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

    Item {
      id: frame
      // In the bar's slot while an attached panel is open, in frameWindow
      // otherwise.
      parent: root.hostSlot ?? frameWindow.contentItem
      // Read by the bar's slot to place it along the bar.
      readonly property string barAlign: root.barAlign
      // An attached frame stays within the bar's span, and leaves room for
      // the bar itself. Whole pixels, so its sides sit on pixel edges, as the
      // curved joins beside them do (see the bar's panelSlot).
      width: Math.floor(Math.min(root.maxPanelWidth, !root.attached ? root.areaWidth * 0.9
        : Theme.barVertical ? root.areaWidth - root.barZone - 20
        : root.areaWidth - Theme.barMarginLeft - Theme.barMarginRight))
      height: Math.floor(Math.min(root.maxPanelHeight, !root.attached ? root.areaHeight * 0.9
        : Theme.barVertical ? root.areaHeight - Theme.barMarginTop - Theme.barMarginBottom
        : root.areaHeight - root.barZone - 20))
      focus: true
      opacity: root.progress

      // Not attached, it grows from a little smaller as it comes in.
      transform: Scale {
        origin.x: frame.width / 2
        origin.y: frame.height / 2
        xScale: root.attached ? 1 : 0.94 + 0.06 * root.progress
        yScale: root.attached ? 1 : 0.94 + 0.06 * root.progress
      }

      // Curves it out of the bar when attached flush against it.
      // None on the side flush with an end of the bar, where there is no bar
      // edge to curve from.
      BarFillets {
        visible: root.attached && root.framed
        showStart: root.barAlign !== "left"
        showEnd: root.barAlign !== "right"
        color: body.color
        borderColor: body.border.color
      }

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

      // Clips the body at the frame's edges (the bar's, on the side against
      // it) while it slides out from under the bar or back.
      Item {
        anchors.fill: parent
        clip: root.attached && root.progress < 1

        Rectangle {
          id: body
          width: frame.width
          height: frame.height
          transform: Translate {
            x: root.slide.x
            y: root.slide.y
          }
          radius: Theme.radiusFor(Math.min(width, height))
          topLeftRadius: root.attached ? Theme.attachedCorner(radius, "topLeft") : radius
          topRightRadius: root.attached ? Theme.attachedCorner(radius, "topRight") : radius
          bottomLeftRadius: root.attached ? Theme.attachedCorner(radius, "bottomLeft") : radius
          bottomRightRadius: root.attached ? Theme.attachedCorner(radius, "bottomRight") : radius
          color: root.framed ? Theme.fade(Theme.pillColor, root.panelOpacity) : "transparent"
          // The border follows the real widget opacity (and Theme.borderOpaque),
          // not `panelOpacity`: a panel like the settings one can clamp its own
          // fill higher to stay readable, but that readability floor isn't a
          // reason to also mute how much the border itself fades.
          border.color: root.framed ? Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity) : "transparent"
          border.width: root.framed ? Theme.borderWidth : 0

          // Content never fades with the widget opacity, same as a bar pill's:
          // only the fill and border do, so text and icons stay fully readable.
          // A separate item from `body` so it doesn't inherit the fill/border's
          // own opacity/color handling.
          Item {
            id: contentHolder
            anchors.fill: parent
          }
        }
      }
    }
  }
}
