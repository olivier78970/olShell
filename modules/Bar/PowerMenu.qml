import QtQuick
import Quickshell
import qs.config

// Power icon that toggles a small logout/restart/shutdown menu below it.
Item {
  id: root

  readonly property bool menuOpen: menu.visible

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  ThemedText {
    id: icon
    anchors.centerIn: parent
    text: ""
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: menu.visible = !menu.visible
  }

  PopupMenu {
    id: menu

    anchorItem: root
    anchor.margins.right: -Theme.pillPadding

    PowerMenuOption {
      icon: ""
      label: I18n.tr("power.logout")
      onClicked: {
        menu.visible = false
        PowerMenuState.request("logout")
      }
    }

    PowerMenuOption {
      icon: ""
      label: I18n.tr("power.restart")
      onClicked: {
        menu.visible = false
        PowerMenuState.request("restart")
      }
    }

    PowerMenuOption {
      icon: ""
      label: I18n.tr("power.shutdown")
      onClicked: {
        menu.visible = false
        PowerMenuState.request("shutdown")
      }
    }
  }
}
