import QtQuick
import qs.components
import qs.config
import qs.services

// Envelope with the Gmail inbox's unread count to its right (under it on a
// side bar), accent-colored while there are unread mails and dimmed while
// the inbox isn't watched (see services/Gmail.qml). Hovering it says what the
// count is or what's wrong; a left click runs its action (Settings.gmailAction:
// a mail app, or a web app) or else opens the inbox in the browser, a
// middle click checks it again now, and a right click opens a menu to turn
// the watching on or off and check it again.
Item {
  id: root

  // Whether the count is known: the inbox is watched and connected.
  readonly property bool counting: Gmail.active && Gmail.unread >= 0
  readonly property color tint: root.counting && Gmail.unread > 0 ? Theme.accentColor : Theme.textColor

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  BarStack {
    id: content
    anchors.centerIn: parent
    gap: 6

    BarText {
      text: ["password", "appPassword", "login"].includes(Gmail.error) ? "󰛏" : (root.counting && Gmail.unread > 0 ? "󰇮" : "󰇰")
      color: Gmail.error === "login" || Gmail.error === "appPassword" ? Theme.warningColor : root.tint
      opacity: root.counting ? 1 : 0.5
    }

    // The number of unread conversations; nothing when there are none.
    BarText {
      visible: root.counting && Gmail.unread > 0
      text: Gmail.unread
      sizeScale: Theme.barFigureScale
      color: root.tint
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      popup.dismiss()
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else if (mouse.button === Qt.MiddleButton) Gmail.lookUpPassword()
      else {
        menu.open = false
        Gmail.openApp()
      }
    }
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  HoverPopup {
    id: popup
    anchorItem: root

    PopupTitle {
      text: I18n.tr("settings.widget.gmail")
    }

    // The account, then the count or what keeps it from being known.
    ThemedText {
      visible: Gmail.address !== ""
      text: Gmail.address
    }

    ThemedText {
      text: !Settings.gmailEnabled || Gmail.address === "" ? I18n.tr("gmail.off")
        : Gmail.error !== "" ? I18n.tr("gmail.error." + Gmail.error)
        : Gmail.unread < 0 ? I18n.tr("gmail.connecting")
        : Gmail.unread === 0 ? I18n.tr("gmail.unread.none")
        : I18n.tr("gmail.unread", Gmail.unread)
    }
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    // The title, with the switch turning the watching on or off.
    MenuSwitchHeading {
      title: true
      text: I18n.tr("settings.widget.gmail")
      checked: Settings.gmailEnabled
      onToggled: Settings.set("gmailEnabled", !Settings.gmailEnabled)
    }

    PowerMenuOption {
      enabled: Gmail.active
      icon: "󰑐"
      label: I18n.tr("gmail.check")
      onClicked: {
        menu.open = false
        Gmail.lookUpPassword()
      }
    }
  }
}
