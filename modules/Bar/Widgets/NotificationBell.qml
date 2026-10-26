import QtQuick
import qs.components
import qs.config
import qs.services

// Bell that opens the notification center. A left click toggles the center, a
// middle click do-not-disturb, a right click opens a menu: its title's switch
// (off while do-not-disturb is on), clearing the center and the notification
// actions. The bell is crossed out while do-not-disturb is
// on. The number of notifications in the center is written to its right (it
// goes down when one is dismissed), or under it on a side bar.
Item {
  id: root

  // Red while an urgent notification is waiting, else accent-colored while
  // there is any.
  readonly property color tint: Notifications.urgent ? Theme.warningColor
    : (Notifications.count > 0 && !Notifications.dnd ? Theme.accentColor : Theme.textColor)

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  BarStack {
    id: content
    anchors.centerIn: parent
    gap: 6

    BarText {
      text: Notifications.dnd ? "󰂛" : "󰂚"
      color: root.tint
    }

    // The number of notifications in the center; nothing when there are none.
    BarText {
      visible: Notifications.count > 0
      text: Notifications.count
      sizeScale: Theme.barFigureScale
      color: root.tint
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else if (mouse.button === Qt.MiddleButton) Notifications.setDnd(!Notifications.dnd)
      else {
        menu.open = false
        NotificationCenterState.toggle()
      }
    }
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    // The title, with the switch letting notifications pop up, or not while
    // do-not-disturb is on (like the Bluetooth and network menus' switches).
    MenuSwitchHeading {
      title: true
      text: I18n.tr("notifications.title")
      checked: !Notifications.dnd
      onToggled: Notifications.setDnd(!Notifications.dnd)
    }

    PowerMenuOption {
      enabled: Notifications.count > 0
      icon: "󰎟"
      label: I18n.tr("notifications.clearAll")
      onClicked: {
        menu.open = false
        Notifications.clear()
      }
    }

    PowerMenuOption {
      icon: "󰒓"
      label: I18n.tr("notificationActions.title")
      onClicked: {
        menu.open = false
        NotificationActionsState.toggle()
      }
    }
  }
}
