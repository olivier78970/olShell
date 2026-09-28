import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services

// The bar, replicated across every connected screen: along the top or bottom
// edge, or standing against the left or right one (Theme.barPosition), its
// widgets then stacked in a column.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: root
      property var modelData
      screen: modelData

      readonly property bool atTop: Theme.barPosition === "top"
      // Whether it stands against a side of the screen, and which.
      readonly property bool vertical: Theme.barVertical
      readonly property bool atLeft: Theme.barPosition === "left"
      readonly property bool autoHide: Theme.barAutoHide
      // Whether the bar is actually drawn right now: always, unless
      // auto-hide is on and the pointer has been away from it for a bit
      // (postponed while one of its own popups is open, so that doesn't
      // get left floating with nothing under it).
      property bool revealed: !root.autoHide
      readonly property bool anyPopupOpen: leftZone.popupOpen || centerZone.popupOpen || rightZone.popupOpen || root.hosting || popupLayer.extent > 0
      // Whether a panel attached to the bar is open on this screen, drawn
      // in panelSlot below.
      readonly property bool hosting: panelSlot.frame !== null
      // The bar's own strip: its height (its width, on a side bar), plus the
      // near margin while auto-hiding (see margins below).
      readonly property real barBlock: Theme.barHeight + (root.autoHide ? root.nearMargin : 0)
      // The margin on the near side (between the true screen edge and the
      // bar itself): the one a hovering pointer has to cross to reach it.
      readonly property int nearMargin: ({ top: Theme.barMarginTop, bottom: Theme.barMarginBottom, left: Theme.barMarginLeft, right: Theme.barMarginRight })[Theme.barPosition]
      // The margin on the far side, between the bar and the windows.
      readonly property int farMargin: ({ top: Theme.barMarginBottom, bottom: Theme.barMarginTop, left: Theme.barMarginRight, right: Theme.barMarginLeft })[Theme.barPosition]
      // How long showing/tucking the bar away takes, in ms: the shell's
      // animation duration, or 0 (snaps instead) with animations turned off.
      readonly property int revealDuration: Theme.animationDuration
      // Whether the bar's own space is reserved right now (see
      // exclusiveZone): true the instant it's revealed, so windows make
      // room for it right as it starts appearing, but only false once its
      // hide animation has actually finished, so they don't reclaim that
      // room while it's still visibly there sliding away.
      property bool spaceReserved: !root.autoHide
      // Settings load a moment after this window's first frame (even with
      // the settings file read synchronously), so any setting saved
      // different from its compile-time default briefly reads that default
      // first: exclusiveZone can end up flipping through a wrong value and
      // straight back to the right one within that same startup instant,
      // which Hyprland doesn't seem to pick up reliably (unlike the same
      // kind of flip happening later, e.g. from hovering the bar away right
      // after it's revealed, which works fine). Holding exclusiveZone at 0
      // until settings have had a moment to settle avoids ever sending that
      // spurious first value in the first place.
      property bool settled: false

      Timer {
        interval: 200
        running: true
        onTriggered: root.settled = true
      }

      onRevealedChanged: {
        if (root.revealed) {
          unreserveTimer.stop()
          root.spaceReserved = true
        } else {
          unreserveTimer.restart()
        }
      }

      Timer {
        id: unreserveTimer
        interval: root.revealDuration
        onTriggered: root.spaceReserved = false
      }
      // Hyprland pads a *stable* reserved layer area with its own gaps_out,
      // but not one that toggles as fast as auto-hide's does (0 while
      // tucked away, the full amount the instant it's revealed) - added
      // into the room reserved below ourselves for that case (see
      // exclusiveZone), so windows end up exactly as far from the bar
      // either way. Kept by services/HyprlandWindows.qml: read from Hyprland,
      // or the shell's own while it syncs the windows' look.
      readonly property real hyprGapsOut: HyprlandWindows.gapsOut[({ top: 2, bottom: 0, left: 1, right: 3 })[Theme.barPosition]]

      onAutoHideChanged: {
        root.revealed = !root.autoHide || stayOpenHover.hovered
        unreserveTimer.stop()
        root.spaceReserved = root.revealed
      }
      onAnyPopupOpenChanged: if (!root.anyPopupOpen && !stayOpenHover.hovered && root.autoHide) hideTimer.restart()
      // A panel opened by IPC while the bar is tucked away brings it back.
      onHostingChanged: {
        if (root.hosting) {
          hideTimer.stop()
          root.revealed = true
          // A panel opening closes any menu still open.
          popupLayer.dismissed()
        }
      }

      // Whether a panel or a menu is open (not just a tooltip): anything
      // else done meanwhile closes it (see dismissAll).
      readonly property bool anyOpen: root.hosting || popupLayer.grabbing

      // Closes the open panel and menus.
      function dismissAll() {
        panelSlot.dismissed()
        popupLayer.dismissed()
      }

      // Switching workspace (by a shortcut, say) closes them too.
      Connections {
        target: Hyprland

        function onRawEvent(event) {
          if (root.anyOpen && event.name === "workspace") root.dismissAll()
        }
      }

      anchors {
        top: atTop || vertical
        bottom: !atTop
        left: atLeft || !vertical
        right: !atLeft
      }

      // While auto-hiding, the window itself spans edge to edge instead of
      // sitting inset by the margins, so hovering into what would otherwise
      // be that gap still counts as reaching for the bar (and the edge the
      // pointer flicks to is actually inside the window, not short of it).
      // The margins become padding on barArea instead, below. Otherwise the
      // window carries them itself, same as always: all but the far one,
      // between the bar and the windows (see exclusiveZone).
      margins.top: root.autoHide || Theme.barPosition === "bottom" ? 0 : Theme.barMarginTop
      margins.bottom: root.autoHide || atTop ? 0 : Theme.barMarginBottom
      margins.left: root.autoHide || Theme.barPosition === "right" ? 0 : Theme.barMarginLeft
      margins.right: root.autoHide || atLeft ? 0 : Theme.barMarginRight

      // Grows (away from the edge: down or up, or sideways for a side bar)
      // to also hold an open attached panel or
      // popup; the room reserved for the bar (exclusiveZone below) stays the
      // same. It never shrinks back, though, only grows to the most it has
      // needed so far (grownBy): Hyprland shows a layer surface's shrink a
      // frame late, and the bar visibly blinked each time a panel or menu
      // closed. What's left past the bar is transparent and masked out from
      // input, so it only costs Hyprland blurring behind it when what's
      // under it changes.
      implicitHeight: vertical ? 0 : root.barBlock + Math.max(root.grownBy, root.neededPast)
      implicitWidth: vertical ? root.barBlock + Math.max(root.grownBy, root.neededPast) : 0
      // How far past the bar the open panel and popups reach right now.
      readonly property real neededPast: Math.max(root.hosting ? (vertical ? panelSlot.width : panelSlot.height) + Theme.panelOffset() : 0, popupLayer.extent)
      property real grownBy: 0
      onNeededPastChanged: root.grownBy = Math.max(root.grownBy, root.neededPast)

      // Moved to another edge, what it grew by for the old one (heights, for
      // a side bar's width, say) no longer means anything.
      Connections {
        target: Theme

        function onBarPositionChanged() {
          root.grownBy = root.neededPast
        }
      }
      // The room the bar keeps free for itself: its height plus the margin
      // on the far side from the edge it's anchored to, so windows start
      // that much further away. Reserved the instant the bar is revealed,
      // so windows make room for it as it appears, but kept reserved until
      // its hide animation has actually finished (spaceReserved, not
      // revealed directly) so they don't reclaim that room while it's still
      // visibly sliding away - with Hyprland's own gap added in ourselves,
      // since it doesn't pad a reservation that comes and goes this fast
      // the way it pads the always-on case.
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: {
        if (!root.settled) return 0
        if (root.autoHide && !root.spaceReserved) return 0
        const zone = Theme.barHeight + root.farMargin
        return root.autoHide ? zone + root.hyprGapsOut : zone
      }
      color: "transparent"

      // While tucked away, only a thin strip flush with the true screen edge
      // accepts input (so the pointer can find it again); the rest passes
      // through to whatever's below. Once revealed, the whole window does
      // (which, while auto-hiding, includes the near/left/right margins:
      // straying into them doesn't lose the bar either).
      // An open attached panel takes input too, but not the rest of the
      // (otherwise transparent) width it grows the window by.
      mask: Region {
        item: (root.autoHide && !root.revealed) ? hoverStrip : fullArea

        Region {
          item: panelSlot
        }

        Region {
          x: popupLayer.x + popupLayer.bounds.x
          y: popupLayer.y + popupLayer.bounds.y
          width: popupLayer.bounds.width
          height: popupLayer.bounds.height
        }
      }

      // An attached panel takes the keyboard while it's open, and a click
      // anywhere outside the bar and its panel or popups closes the panel
      // and any menu (the focus grab ends).
      WlrLayershell.keyboardFocus: root.anyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      HyprlandFocusGrab {
        active: root.anyOpen
        windows: [root]
        onCleared: root.dismissAll()
      }

      // While a panel or menu is open, an invisible surface over the whole
      // screen but that panel or menu (the bar included) takes any click
      // elsewhere, closes them and swallows it, as a click outside a menu
      // usually does: on another bar widget, a window or the desktop. Its
      // own namespace keeps it out of the blur rule (see services/Blur.qml).
      PanelWindow {
        id: clickCatcher

        // The bar window's own on-screen origin (see its anchors and
        // margins above), to place the panel and popups' holes.
        readonly property real originX: Theme.barPosition === "right"
          ? root.screen.width - (root.autoHide ? 0 : Theme.barMarginRight) - root.width
          : (root.autoHide ? 0 : Theme.barMarginLeft)
        readonly property real originY: Theme.barPosition === "bottom"
          ? root.screen.height - (root.autoHide ? 0 : Theme.barMarginBottom) - root.height
          : (root.autoHide ? 0 : Theme.barMarginTop)

        visible: root.anyOpen
        screen: root.screen

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

        mask: Region {
          item: catcherArea

          Region {
            intersection: Intersection.Subtract
            x: clickCatcher.originX + panelSlot.x
            y: clickCatcher.originY + panelSlot.y
            width: panelSlot.width
            height: panelSlot.height
          }

          Region {
            intersection: Intersection.Subtract
            x: clickCatcher.originX + popupLayer.x + popupLayer.bounds.x
            y: clickCatcher.originY + popupLayer.y + popupLayer.bounds.y
            width: popupLayer.bounds.width
            height: popupLayer.bounds.height
          }
        }

        MouseArea {
          id: catcherArea
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onPressed: root.dismissAll()
        }
      }

      // Flush with the true screen edge, for the click-through mask above
      // and as a natural resting place once revealed by hovering it slowly.
      Item {
        id: hoverStrip
        readonly property real depth: 10
        x: vertical && !atLeft ? parent.width - width : 0
        y: !vertical && !atTop ? parent.height - height : 0
        width: vertical ? depth : parent.width
        height: vertical ? parent.height : depth
      }

      // Reveals the bar once the pointer reaches the true screen edge.
      // Deliberately not a HoverHandler/mask-based edge trigger: a fast
      // flick to the edge can cross a masked-in strip between two pointer
      // motion samples without ever generating an event inside it (and, on
      // this compositor, even the ones that do land often don't repaint the
      // surface in time). Polling Hyprland's own cursor position instead
      // doesn't depend on catching a transient crossing event at all.
      Timer {
        interval: 50
        running: root.autoHide && !root.revealed
        repeat: true
        onTriggered: edgeCheck.running = true
      }

      Process {
        id: edgeCheck
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
          onStreamFinished: {
            const parts = text.trim().split(",").map(s => parseInt(s.trim(), 10))
            if (parts.length !== 2 || parts.some(isNaN)) return
            const [cx, cy] = parts
            const withinX = cx >= root.screen.x && cx < root.screen.x + root.screen.width
            const withinY = cy >= root.screen.y && cy < root.screen.y + root.screen.height
            const depth = hoverStrip.depth
            const nearEdge = ({
              top: withinX && cy <= root.screen.y + depth,
              bottom: withinX && cy >= root.screen.y + root.screen.height - depth,
              left: withinY && cx <= root.screen.x + depth,
              right: withinY && cx >= root.screen.x + root.screen.width - depth
            })[Theme.barPosition]
            if (nearEdge) {
              hideTimer.stop()
              root.revealed = true
            }
          }
        }
      }

      Timer {
        id: hideTimer
        interval: Theme.barAutoHideDelay
        onTriggered: root.revealed = false
      }

      Item {
        id: fullArea
        // Placed by hand rather than anchored: switching anchors along with
        // the size, as the bar moves between edges, left the old size in place.
        x: vertical && !atLeft ? parent.width - width : 0
        y: !vertical && !atTop ? parent.height - height : 0
        width: vertical ? root.barBlock : parent.width
        height: vertical ? parent.height : root.barBlock

        // Once revealed, the pointer being anywhere in the bar or its
        // margins (not just the edge strip above) keeps it open.
        HoverHandler {
          id: stayOpenHover
          onHoveredChanged: if (!stayOpenHover.hovered && root.autoHide && !root.anyPopupOpen) hideTimer.restart()
        }

        // Where the bar itself actually sits: fullArea's own size, inset by
        // the margins that would otherwise have been the window's (only
        // while auto-hiding put them here instead; the window already
        // carries them otherwise, so no inset is needed then). Slides
        // in/out past the near edge and fades, rather than snapping, while
        // auto-hiding (always at rest, no offset, otherwise).
        Item {
          id: barArea
          // The margins it's inset by, on each side (see above), placed by
          // hand like fullArea.
          readonly property real insetLeft: root.autoHide && Theme.barPosition !== "right" ? Theme.barMarginLeft : 0
          readonly property real insetRight: root.autoHide && !atLeft ? Theme.barMarginRight : 0
          readonly property real insetTop: root.autoHide && Theme.barPosition !== "bottom" ? Theme.barMarginTop : 0
          readonly property real insetBottom: root.autoHide && !atTop ? Theme.barMarginBottom : 0
          x: vertical && !atLeft ? parent.width - width - insetRight : insetLeft
          y: !vertical && !atTop ? parent.height - height - insetBottom : insetTop
          width: vertical ? Theme.barHeight : parent.width - insetLeft - insetRight
          height: vertical ? parent.height - insetTop - insetBottom : Theme.barHeight
          opacity: root.revealed ? 1 : 0

          Behavior on opacity {
            NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
          }

          transform: Translate {
            x: root.revealed || !vertical ? 0 : (atLeft ? -barArea.width : barArea.width)
            y: root.revealed || vertical ? 0 : (atTop ? -barArea.height : barArea.height)

            Behavior on x {
              NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
            }

            Behavior on y {
              NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
            }
          }

          // The bar's own background, the same color as its widget pills,
          // shown only in the "full" barStyle (the pills' own backgrounds go
          // transparent instead, see Pill.qml). The same Theme.widgetOpacity
          // as every other surface controls it, so there's one opacity
          // setting for the whole shell instead of a separate one for the bar.
          Rectangle {
            anchors.fill: parent
            visible: Theme.barStyle === "full"
            radius: Theme.radiusFor(Math.min(width, height))
            // Squared off where a popup flush with an end of the bar joins it.
            topLeftRadius: Theme.flatBarCorner("topLeft", popupLayer.atStartEnd, popupLayer.atEndEnd) ? 0 : radius
            topRightRadius: Theme.flatBarCorner("topRight", popupLayer.atStartEnd, popupLayer.atEndEnd) ? 0 : radius
            bottomLeftRadius: Theme.flatBarCorner("bottomLeft", popupLayer.atStartEnd, popupLayer.atEndEnd) ? 0 : radius
            bottomRightRadius: Theme.flatBarCorner("bottomRight", popupLayer.atStartEnd, popupLayer.atEndEnd) ? 0 : radius
            color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
            border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
            border.width: Theme.borderWidth
          }

          // Left widgets (at the top, on a side bar). Placed by hand rather
          // than anchored: switching anchors as the bar moves between edges
          // briefly anchored both its top and its middle, which fixed its
          // height for good.
          WidgetZone {
            id: leftZone
            x: vertical ? (parent.width - width) / 2 : 0
            y: vertical ? 0 : (parent.height - height) / 2
            widgets: Settings.layout.left
            flattenStartPopupCorner: popupLayer.atStartEnd
          }

          // Middle widgets
          WidgetZone {
            id: centerZone
            anchors.centerIn: parent
            widgets: Settings.layout.center
          }

          // Right widgets (at the bottom, on a side bar), placed the same way.
          WidgetZone {
            id: rightZone
            x: vertical ? (parent.width - width) / 2 : parent.width - width
            y: vertical ? parent.height - height : (parent.height - height) / 2
            widgets: Settings.layout.right
            flattenEndPopupCorner: popupLayer.atEndEnd
          }
        }
      }

      // Where an attached panel's frame is drawn while it's open on this
      // screen (see config/BarSlots.qml): sized to the frame, centered on the
      // screen along the bar or flush with an end of it (following the
      // frame's barAlign, see components/ModalPanel.qml; "left" is the top
      // end of a side bar), Theme.panelOffset() away from the bar.
      Item {
        id: panelSlot

        readonly property var screen: root.screen
        readonly property Item frame: panelSlot.children.length > 0 ? panelSlot.children[0] : null
        // Where along the bar the frame goes: "left", "center" or "right".
        readonly property string align: panelSlot.frame?.barAlign ?? "center"
        // The frame's length along the bar, and where it starts along it.
        readonly property real length: vertical ? panelSlot.height : panelSlot.width
        readonly property real along: Math.round(panelSlot.align === "left" ? popupLayer.barStart
          : panelSlot.align === "right" ? popupLayer.barEnd - panelSlot.length
          : vertical ? root.screen.height / 2 - (root.autoHide ? 0 : Theme.barMarginTop) - panelSlot.length / 2
          : root.screen.width / 2 - (root.autoHide ? 0 : Theme.barMarginLeft) - panelSlot.length / 2)

        // A click outside the bar and panel: the panel should close.
        signal dismissed()

        // On whole pixels: at a fraction the frame's sides and the curved
        // joins beside them (components/BarFillets.qml) are both drawn half
        // transparent along their seam, which then shows as a thin line.
        x: !vertical ? panelSlot.along
          : atLeft ? root.barBlock + Theme.panelOffset() : root.width - root.barBlock - Theme.panelOffset() - panelSlot.width
        y: vertical ? panelSlot.along
          : atTop ? root.barBlock + Theme.panelOffset() : 0
        width: panelSlot.frame ? panelSlot.frame.width : 0
        height: panelSlot.frame ? panelSlot.frame.height : 0

        Component.onCompleted: BarSlots.register(panelSlot)
        Component.onDestruction: BarSlots.unregister(panelSlot)
      }

      // Where the widgets' popups and menus are drawn while shown (see
      // components/PopupMenu.qml), each placing itself off its widget. Its
      // origin is on the bar's edge toward the middle of the screen, so the
      // popups' positions don't depend on how far the window grows for them:
      // they go at positive coordinates across the bar from a top or left
      // bar, at negative ones from a bottom or right one.
      Item {
        id: popupLayer

        readonly property var screen: root.screen
        // The popups showing now.
        readonly property var shown: {
          const items = []
          for (const child of popupLayer.children) {
            if (child?.visible) items.push(child)
          }
          return items
        }
        // How far past the bar they reach, for the window to grow by.
        readonly property real extent: popupLayer.shown.reduce((most, item) => Math.max(most, popupLayer.reach(item)), 0)

        // How far past the bar `item` reaches.
        function reach(item) {
          if (vertical) return atLeft ? item.x + item.width : -item.x
          return atTop ? item.y + item.height : -item.y
        }

        // Where `item` starts and ends along the bar.
        function startOf(item) {
          return vertical ? item.y : item.x
        }

        function endOf(item) {
          return vertical ? item.y + item.height : item.x + item.width
        }
        // The rectangle they span (in this layer), for the input mask.
        readonly property rect bounds: {
          if (popupLayer.shown.length === 0) return Qt.rect(0, 0, 0, 0)
          const left = Math.min(...popupLayer.shown.map(item => item.x))
          const top = Math.min(...popupLayer.shown.map(item => item.y))
          const right = Math.max(...popupLayer.shown.map(item => item.x + item.width))
          const bottom = Math.max(...popupLayer.shown.map(item => item.y + item.height))
          return Qt.rect(left, top, right - left, bottom - top)
        }
        // Whether one of them, flush with the bar (no gap set), reaches its
        // start (left, or top on a side bar) or its end: that corner of the
        // bar (or of its end pill) is squared off so the two join up, as they
        // do along the bar's edge. An attached panel flush with an end of the
        // bar counts too.
        readonly property bool atStartEnd: Theme.panelGap <= 0
          && (popupLayer.shown.some(item => popupLayer.touchesBar(item) && popupLayer.startOf(item) <= popupLayer.barStart + 0.5)
            || (root.hosting && panelSlot.align === "left"))
        readonly property bool atEndEnd: Theme.panelGap <= 0
          && (popupLayer.shown.some(item => popupLayer.touchesBar(item) && popupLayer.endOf(item) >= popupLayer.barEnd - 0.5)
            || (root.hosting && panelSlot.align === "right"))

        // Where the bar itself starts and ends along its length, in the layer
        // (shorter than the window while auto-hiding, see barArea), which
        // popups stay within.
        readonly property real barStart: vertical ? barArea.y : barArea.x
        readonly property real barEnd: vertical ? barArea.y + barArea.height : barArea.x + barArea.width

        function touchesBar(item) {
          if (vertical) return atLeft ? item.x <= 0 : item.x + item.width >= 0
          return atTop ? item.y <= 0 : item.y + item.height >= 0
        }

        // Whether one of them closes on a click outside (a menu, not a tooltip).
        readonly property bool grabbing: popupLayer.shown.some(item => item.grabFocus)

        // A click outside the bar and its popups: menus should close.
        signal dismissed()

        width: vertical ? 0 : parent.width
        height: vertical ? parent.height : 0
        x: !vertical ? 0 : atLeft ? root.barBlock : root.width - root.barBlock
        y: vertical ? 0 : atTop ? root.barBlock : root.height - root.barBlock

        Component.onCompleted: BarSlots.registerPopupLayer(popupLayer)
        Component.onDestruction: BarSlots.unregisterPopupLayer(popupLayer)
      }
    }
  }
}
