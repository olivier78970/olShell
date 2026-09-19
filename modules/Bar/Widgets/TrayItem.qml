import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config

// A single system tray icon: left click activates, right click opens
// its context menu (if any), middle click triggers secondary activation.
Item {
  id: root

  // Bound directly by Repeater as a required property (rather than read
  // via a plain `modelData` expression) so it can't be shadowed by an
  // ancestor's own `property var modelData` (e.g. the screen Variants).
  required property var modelData
  readonly property var trayItem: modelData

  implicitWidth: Theme.trayIconSize()
  implicitHeight: Theme.trayIconSize()

  IconImage {
    anchors.fill: parent
    source: root.trayItem.icon ?? ""
    asynchronous: true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton && !root.trayItem.onlyMenu) {
        root.trayItem.activate()
      } else if (mouse.button === Qt.MiddleButton) {
        root.trayItem.secondaryActivate()
      } else if (root.trayItem.hasMenu) {
        menu.visible = !menu.visible
      }
    }

    onEntered: tooltip.hoverEntered()
    onExited: tooltip.hoverExited()
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.trayItem.menu
  }

  PopupMenu {
    id: menu
    anchorItem: root
    anchor.margins.right: -Theme.pillPadding

    Repeater {
      model: menuOpener.children

      TrayMenuItem {
        onActivated: menu.visible = false
      }
    }
  }

  HoverPopup {
    id: tooltip
    anchorItem: root
    anchor.margins.right: -Theme.pillPadding
    showWhen: !menu.visible

    ThemedText {
      text: root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id
    }

    ThemedText {
      visible: text.length > 0
      text: root.trayItem.tooltipDescription
      sizeScale: 0.85
    }
  }
}
