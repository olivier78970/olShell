import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The pop-ups: the newest notifications, stacked in a corner or at the middle
// of an edge (or halfway down the left or right one) of the focused screen (Settings.notificationPosition;
// under the bar at the top). The newest is the one nearest the edge. The window
// is only as big as the pop-ups, so clicks elsewhere reach the windows below.
//
// At the top under a top bar (not auto-hiding), they're drawn inside the bar
// itself instead, in its popup layer (see config/BarSlots.qml), like the bar
// widgets' popups: blurred together with the bar rather than picking up its
// fill along the seam, and with no gap set, flush with it (squaring off the
// bar's own corner at its ends) and curved out of it (see
// components/BarFillets.qml). With no gap set, wherever they are, the stack
// reads as one block: every corner squared off but the last card's bottom
// ones (see NotificationCard).
PanelWindow {
  id: root

  readonly property bool showing: Notifications.popups.length > 0 && !NotificationCenterState.visible
  // The bar's popup layer they're drawn in, if they're against the bar.
  readonly property Item host: Notifications.atTop && Theme.barPosition !== "bottom" && !Theme.barAutoHide
    ? BarSlots.popupLayerFor(Notifications.screen) : null

  screen: Notifications.screen
  // With neither side anchored the window is centered.
  anchors {
    top: Notifications.atTop
    bottom: Notifications.atBottom
    left: Notifications.atLeft
    right: Notifications.atRight
  }
  // From the bar (measured from the room it reserves), the same gap as the
  // panels attached to it (Theme.panelOffset: the gap setting, or with none,
  // flush, overlapping its border); from the bare screen edge, a fixed margin.
  margins.top: Theme.barPosition !== "bottom" ? Theme.panelOffset() : 10
  margins.bottom: Theme.barPosition === "bottom" ? Theme.panelOffset() : 10
  margins.left: Theme.barMarginLeft
  margins.right: Theme.barMarginRight

  implicitWidth: stack.width
  implicitHeight: Math.max(1, column.implicitHeight)
  color: "transparent"
  aboveWindows: true
  focusable: false
  // Respects the bar's reserved room (so it starts under the bar) without
  // reserving any of its own.
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  // Nothing to show, or drawn in the bar: no window at all. The center
  // shows them instead of pop-ups while it's open.
  visible: root.showing && root.host === null

  Item {
    id: stack

    // In the bar's popup layer, where it's the same gap below the bar and
    // lined up with the bar's ends (or centered on it) as this window would
    // be; in this window otherwise.
    parent: root.host ?? root.contentItem
    visible: root.showing
    width: 380
    height: column.implicitHeight
    x: {
      if (!root.host) return 0
      if (Notifications.atLeft) return root.host.barLeft
      if (Notifications.atRight) return root.host.barRight - stack.width
      return Math.round((root.host.barLeft + root.host.barRight - stack.width) / 2)
    }
    y: root.host ? Theme.panelOffset() : 0

    Column {
      id: column
      width: parent.width
      // The same gap between them as from the bar (with none, touching,
      // their borders overlapping).
      spacing: Theme.panelOffset()

      Repeater {
        id: cards

        model: ScriptModel {
          values: Notifications.atBottom ? Notifications.popups.slice().reverse() : Notifications.popups
        }

        NotificationCard {
          required property var modelData
          required property int index

          width: column.width
          entry: modelData
          toast: true
          inStack: true
          lastInStack: index === cards.count - 1
        }
      }
    }

    // The newest's curves out of the bar, beside it (the card clips what's
    // drawn inside it), on each side not flush with an end of the bar.
    Item {
      readonly property Item card: cards.count > 0 ? cards.itemAt(0) : null

      visible: root.host !== null && card !== null
      width: stack.width
      height: card ? card.height : 0

      BarFillets {
        size: parent.card ? parent.card.radius : 0
        color: parent.card ? parent.card.color : "transparent"
        borderColor: parent.card ? parent.card.border.color : "transparent"
        showLeft: root.host !== null && stack.x > root.host.barLeft + 0.5
        showRight: root.host !== null && stack.x + stack.width < root.host.barRight - 0.5
      }
    }
  }
}
