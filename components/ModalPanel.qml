import QtQuick
import Quickshell
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
PanelWindow {
  id: root

  // Design size of the frame; it shrinks to fit smaller screens.
  property real maxPanelWidth: 800
  property real maxPanelHeight: 600
  // Opacity of the frame; the settings panel keeps it high so it stays
  // readable while the widget opacity is being adjusted.
  property real panelOpacity: Theme.widgetOpacity
  // Whether the frame is drawn; without it only the children show, over the
  // dimmed backdrop.
  property bool framed: true
  // Gets keyboard focus each time the panel opens (default: the frame).
  property Item focusTarget: frame

  // The frame, e.g. to size content from it.
  readonly property Item panel: frame
  default property alias content: frame.data

  signal closeRequested()
  // Emitted each time the panel becomes visible.
  signal opened()
  // A key that neither Escape nor the focused item used; set
  // `event.accepted = true` to consume it.
  signal keyPressed(var event)

  WlrLayershell.layer: WlrLayer.Overlay
  // Grabs all keyboard input while open, so shortcuts/typing never leak
  // to whatever's behind the panel.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

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
  focusable: true
  // Ignore the bar's reserved exclusive zone so the backdrop covers the
  // whole screen, including the strip behind the top bar.
  exclusionMode: ExclusionMode.Ignore

  onVisibleChanged: {
    if (root.visible) {
      root.focusTarget.forceActiveFocus()
      root.opened()
    }
  }

  // Dimmed backdrop covering the whole screen; clicking it closes the
  // panel, like clicking outside any other modal dialog. Closing is
  // gated on the click landing outside the panel's own bounds (rather
  // than relying on a swallowing MouseArea on the panel) so nothing
  // inside it - including actions that don't otherwise consume the
  // click - can ever be misread as an outside click.
  MouseArea {
    anchors.fill: parent
    onClicked: mouse => {
      const point = mapToItem(frame, mouse.x, mouse.y)
      const insidePanel = point.x >= 0 && point.x <= frame.width && point.y >= 0 && point.y <= frame.height
      if (!insidePanel) root.closeRequested()
    }

    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: 0.4
    }
  }

  Rectangle {
    id: frame
    anchors.centerIn: parent
    width: Math.min(root.maxPanelWidth, root.width * 0.9)
    height: Math.min(root.maxPanelHeight, root.height * 0.9)
    radius: Theme.radiusFor(height)
    color: root.framed ? Theme.pillColor : "transparent"
    border.color: root.framed ? Theme.outlineColor : "transparent"
    border.width: root.framed ? Theme.borderWidth : 0
    opacity: root.framed ? root.panelOpacity : 1
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

    // Swallow clicks on the panel itself so they don't fall through to
    // the backdrop's MouseArea and close the panel.
    MouseArea {
      anchors.fill: parent
    }
  }
}
