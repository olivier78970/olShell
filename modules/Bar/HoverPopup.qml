import QtQuick
import qs.config

// Tooltip-style PopupMenu shown while the pointer hovers a widget. Call
// hoverEntered()/hoverExited() from the widget's MouseArea; set `showWhen`
// for extra conditions that must also hold (e.g. only when text is cut off),
// and `keepOpen` for popups the pointer needs to move into.
PopupMenu {
  id: root

  property int showDelay: 500
  property int hideDelay: 150
  property bool showWhen: true
  property bool hovering: false
  // Stay open while the pointer is over the popup itself (needed for
  // interactive content), not just over the widget.
  property bool keepOpen: false

  grabFocus: false
  visible: root.hovering && root.showWhen

  onContainsMouseChanged: {
    if (!root.keepOpen) return
    if (root.containsMouse) root.hoverEntered()
    else root.hoverExited()
  }

  function hoverEntered() {
    hideTimer.stop()
    showTimer.restart()
  }

  function hoverExited() {
    showTimer.stop()
    hideTimer.restart()
  }

  // Delay before showing, so quickly passing over the widget doesn't pop
  // it open.
  Timer {
    id: showTimer
    interval: root.showDelay
    onTriggered: root.hovering = true
  }

  // Debounces hover-out so a brief/spurious leave event (e.g. from the
  // popup surface appearing right next to the widget) doesn't instantly
  // dismiss it.
  Timer {
    id: hideTimer
    interval: root.hideDelay
    onTriggered: root.hovering = false
  }
}
