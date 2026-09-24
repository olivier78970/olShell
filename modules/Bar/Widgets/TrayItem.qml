import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// A single system tray icon: left click activates (or does what
// Apps.trayLeftClick says for this icon), right click opens its context menu
// (if any), middle click triggers secondary activation.
Item {
  id: root

  // Bound directly by Repeater as a required property (rather than read
  // via a plain `modelData` expression) so it can't be shadowed by an
  // ancestor's own `property var modelData` (e.g. the screen Variants).
  required property var modelData
  readonly property var trayItem: modelData

  // Replaces the left click's usual activation, if Apps.trayLeftClick says so.
  readonly property string leftClick: Apps.trayLeftClick[trayItem.id] ?? ""

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
      if (mouse.button === Qt.LeftButton && root.leftClick === "bluetui") {
        Bluetui.toggle()
      } else if (mouse.button === Qt.LeftButton && !root.trayItem.onlyMenu) {
        root.trayItem.activate()
      } else if (mouse.button === Qt.MiddleButton) {
        root.trayItem.secondaryActivate()
      } else if (root.trayItem.hasMenu) {
        contextMenu.visible = !contextMenu.visible
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
    id: contextMenu
    anchorItem: root
    marginRight: -Theme.pillPadding

    Repeater {
      model: menuOpener.children

      TrayMenuItem {
        menu: contextMenu
        rootMenu: contextMenu
        onActivated: contextMenu.visible = false
      }
    }
  }

  HoverPopup {
    id: tooltip
    anchorItem: root
    marginRight: -Theme.pillPadding
    showWhen: !contextMenu.visible

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
