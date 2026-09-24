import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config

// Icon and title of the currently focused window (any compositor
// supporting wlr-foreign-toplevel-management, not just Hyprland).
Row {
  id: root

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property var desktopEntry: root.toplevel ? DesktopEntries.byId(root.toplevel.appId) : null
  readonly property int maxTitleWidth: 700

  anchors.verticalCenter: parent.verticalCenter
  spacing: 8
  // Whether there is a window to show; the bar's slot hides the widget (and the
  // divider before it) when there isn't.
  readonly property bool present: root.toplevel !== null
  visible: root.present

  IconImage {
    anchors.verticalCenter: parent.verticalCenter
    width: Theme.trayIconSize()
    height: Theme.trayIconSize()
    source: root.desktopEntry ? Quickshell.iconPath(root.desktopEntry.icon)
      : (root.toplevel ? Quickshell.iconPath(root.toplevel.appId, true) : "")
  }

  ThemedText {
    id: titleText
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, root.maxTitleWidth)
    text: root.toplevel ? root.toplevel.title : ""
    elide: Text.ElideRight

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: titleText.truncated ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: tooltip.hoverEntered()
      onExited: tooltip.hoverExited()
    }
  }

  HoverPopup {
    id: tooltip
    anchorItem: root
    alignLeft: true
    marginLeft: -Theme.pillPadding
    // Only worth showing when the title is actually cut off.
    showWhen: titleText.truncated

    ThemedText {
      text: titleText.text
    }
  }
}
