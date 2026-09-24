import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.config

// Top bar, replicated across every connected screen.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: root
      property var modelData
      screen: modelData

      readonly property bool atTop: Theme.barPosition === "top"
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
      // The bar's own strip: its height, plus the near margin while
      // auto-hiding (see margins below).
      readonly property real barBlock: Theme.barHeight + (root.autoHide ? root.nearMargin : 0)
      // The margin on the near side (between the true screen edge and the
      // bar itself): the one a hovering pointer has to cross to reach it.
      readonly property int nearMargin: atTop ? Theme.barMarginTop : Theme.barMarginBottom
      // How long showing/tucking the bar away takes, in ms; 0 (snaps
      // instead) when animating it is turned off.
      readonly property int revealDuration: Theme.barAutoHideAnimated ? Theme.barAutoHideDuration : 0
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
      // either way. Queried once at startup; a `gaps_out` changed by
      // reloading the Hyprland config needs the shell restarted too.
      property real hyprGapsOut: 0

      Process {
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        running: true
        stdout: StdioCollector {
          onStreamFinished: {
            try {
              const values = JSON.parse(text).css.trim().split(/\s+/).map(Number)
              const value = values[atTop ? Math.min(2, values.length - 1) : 0]
              if (!isNaN(value)) root.hyprGapsOut = value
            } catch (e) {}
          }
        }
      }

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
        }
      }

      anchors {
        top: atTop
        bottom: !atTop
        left: true
        right: true
      }

      // While auto-hiding, the window itself spans edge to edge instead of
      // sitting inset by the margins, so hovering into what would otherwise
      // be that gap still counts as reaching for the bar (and the edge the
      // pointer flicks to is actually inside the window, not short of it).
      // The margins become padding on barArea instead, below. Otherwise the
      // window carries them itself, same as always.
      margins.top: root.autoHide ? 0 : (atTop ? Theme.barMarginTop : 0)
      margins.bottom: root.autoHide ? 0 : (atTop ? 0 : Theme.barMarginBottom)
      margins.left: root.autoHide ? 0 : Theme.barMarginLeft
      margins.right: root.autoHide ? 0 : Theme.barMarginRight

      // Grows (away from the edge) to also hold an open attached panel; the
      // room reserved for the bar (exclusiveZone below) stays the same.
      implicitHeight: root.barBlock + Math.max(root.hosting ? panelSlot.height + Theme.panelOffset() : 0, popupLayer.extent)
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
        const zone = Theme.barHeight + (atTop ? Theme.barMarginBottom : Theme.barMarginTop)
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
          x: popupLayer.bounds.x
          y: popupLayer.y + popupLayer.bounds.y
          width: popupLayer.bounds.width
          height: popupLayer.bounds.height
        }
      }

      // An attached panel takes the keyboard while it's open, and a click
      // anywhere outside the bar and its panel or popups closes the panel
      // and any menu (the focus grab ends).
      WlrLayershell.keyboardFocus: root.hosting || popupLayer.grabbing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      HyprlandFocusGrab {
        active: root.hosting || popupLayer.grabbing
        windows: [root]
        onCleared: {
          panelSlot.dismissed()
          popupLayer.dismissed()
        }
      }

      // Flush with the true screen edge, for the click-through mask above
      // and as a natural resting place once revealed by hovering it slowly.
      Item {
        id: hoverStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: atTop ? parent.top : undefined
        anchors.bottom: atTop ? undefined : parent.bottom
        height: 10
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
            const nearEdge = atTop ? cy <= root.screen.y + hoverStrip.height : cy >= root.screen.y + root.screen.height - hoverStrip.height
            if (withinX && nearEdge) {
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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: atTop ? parent.top : undefined
        anchors.bottom: atTop ? undefined : parent.bottom
        height: root.barBlock

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
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: root.autoHide ? Theme.barMarginLeft : 0
          anchors.rightMargin: root.autoHide ? Theme.barMarginRight : 0
          anchors.top: atTop ? parent.top : undefined
          anchors.bottom: atTop ? undefined : parent.bottom
          anchors.topMargin: root.autoHide && atTop ? root.nearMargin : 0
          anchors.bottomMargin: root.autoHide && !atTop ? root.nearMargin : 0
          height: Theme.barHeight
          opacity: root.revealed ? 1 : 0

          Behavior on opacity {
            NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
          }

          transform: Translate {
            y: root.revealed ? 0 : (atTop ? -barArea.height : barArea.height)

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
            radius: Theme.radiusFor(height)
            color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
            border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
            border.width: Theme.borderWidth
          }

          // Left widgets
          WidgetZone {
            id: leftZone
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            widgets: Settings.layout.left
          }

          // Middle widgets
          WidgetZone {
            id: centerZone
            anchors.centerIn: parent
            widgets: Settings.layout.center
          }

          // Right widgets
          WidgetZone {
            id: rightZone
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            widgets: Settings.layout.right
            flattenPopupCorner: popupOpen
          }
        }
      }

      // Where an attached panel's frame is drawn while it's open on this
      // screen (see config/BarSlots.qml): sized to the frame, horizontally
      // centered on the screen, Theme.panelOffset() away from the bar.
      Item {
        id: panelSlot

        readonly property var screen: root.screen
        readonly property Item frame: panelSlot.children.length > 0 ? panelSlot.children[0] : null

        // A click outside the bar and panel: the panel should close.
        signal dismissed()

        x: root.screen.width / 2 - (root.autoHide ? 0 : Theme.barMarginLeft) - panelSlot.width / 2
        y: atTop ? root.barBlock + Theme.panelOffset() : 0
        width: panelSlot.frame ? panelSlot.frame.width : 0
        height: panelSlot.frame ? panelSlot.frame.height : 0

        Component.onCompleted: BarSlots.register(panelSlot)
        Component.onDestruction: BarSlots.unregister(panelSlot)
      }

      // Where the widgets' popups and menus are drawn while shown (see
      // components/PopupMenu.qml), each placing itself off its widget. Its
      // origin is on the bar's edge toward the middle of the screen, so the
      // popups' positions don't depend on how far the window grows for them.
      Item {
        id: popupLayer

        readonly property var screen: root.screen
        // The popups showing now.
        readonly property var shown: {
          const items = []
          for (const child of popupLayer.children) {
            if (child.visible) items.push(child)
          }
          return items
        }
        // How far past the bar they reach, for the window to grow by.
        readonly property real extent: popupLayer.shown.reduce((most, item) => Math.max(most, atTop ? item.y + item.height : -item.y), 0)
        // The rectangle they span (in this layer), for the input mask.
        readonly property rect bounds: {
          if (popupLayer.shown.length === 0) return Qt.rect(0, 0, 0, 0)
          const left = Math.min(...popupLayer.shown.map(item => item.x))
          const top = Math.min(...popupLayer.shown.map(item => item.y))
          const right = Math.max(...popupLayer.shown.map(item => item.x + item.width))
          const bottom = Math.max(...popupLayer.shown.map(item => item.y + item.height))
          return Qt.rect(left, top, right - left, bottom - top)
        }
        // Whether one of them closes on a click outside (a menu, not a tooltip).
        readonly property bool grabbing: popupLayer.shown.some(item => item.grabFocus)

        // A click outside the bar and its popups: menus should close.
        signal dismissed()

        width: parent.width
        height: 0
        y: atTop ? root.barBlock : root.height - root.barBlock

        Component.onCompleted: BarSlots.registerPopupLayer(popupLayer)
        Component.onDestruction: BarSlots.unregisterPopupLayer(popupLayer)
      }
    }
  }
}
