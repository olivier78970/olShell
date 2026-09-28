import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The notification center: every notification received, by application,
// placed like the other panels (Settings.notificationCenterPlacement, see
// ModalPanel's `placement`): against the bar's middle by default, on the
// focused screen. Opening it puts the pop-ups away, as it shows them.
// Escape or a click outside closes it.
ModalPanel {
  id: root

  // The room around the header and the list.
  readonly property real inset: 16

  // As tall as its notifications (the screen caps it; the rest scroll).
  maxPanelWidth: 440
  maxPanelHeight: root.inset * 2 + header.height + 12 + Math.max(list.contentHeight, empty.height)
  placement: Settings.notificationCenterPlacement

  open: NotificationCenterState.visible
  onCloseRequested: NotificationCenterState.visible = false
  onOpened: Notifications.hideAllPopups()

  // A notification arriving while the center is open shows in it, not as a pop-up.
  Connections {
    target: Notifications

    function onEntriesChanged() {
      if (root.open) Notifications.hideAllPopups()
    }
  }

  Row {
    id: header
    x: root.inset
    y: root.inset
    width: parent.width - root.inset * 2
    spacing: 4

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - buttons.width - parent.spacing
      text: I18n.tr("notifications.title")
      sizeScale: 1.1
      font.bold: true
      elide: Text.ElideRight
    }

    Row {
      id: buttons
      anchors.verticalCenter: parent.verticalCenter

      IconButton {
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        sizeScale: 1.2
        onClicked: Notifications.setDnd(!Notifications.dnd)

        // Lit while do-not-disturb is on.
        Rectangle {
          visible: Notifications.dnd
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: 14
          height: 2
          color: Theme.accentColor
        }
      }

      IconButton {
        icon: "󰆴"
        sizeScale: 1.2
        enabled: Notifications.entries.length > 0
        onClicked: Notifications.clear()
      }
    }
  }

  // What shows when there is nothing.
  Column {
    id: empty
    visible: Notifications.entries.length === 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.inset + header.height + 12
    spacing: 8
    height: 120

    Item {
      width: 1
      height: 20
    }

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Notifications.dnd ? "󰂛" : "󰂚"
      sizeScale: 2.5
      opacity: 0.4
    }

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: I18n.tr(Notifications.dnd ? "notifications.emptyDnd" : "notifications.empty")
      opacity: 0.6
    }
  }

  ListView {
    id: list
    x: root.inset
    y: root.inset + header.height + 12
    width: parent.width - root.inset * 2
    height: parent.height - y - root.inset
    clip: true
    spacing: 14
    boundsBehavior: Flickable.StopAtBounds
    visible: Notifications.entries.length > 0

    model: ScriptModel {
      values: Notifications.groups
      objectProp: "app"
    }

    delegate: Column {
      id: group

      required property var modelData

      width: list.width
      spacing: 8

      Row {
        width: parent.width

        ThemedText {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - clearGroup.width
          text: group.modelData.app !== "" ? group.modelData.app : I18n.tr("notifications.unknown")
          sizeScale: 0.8
          opacity: 0.7
          font.bold: true
          elide: Text.ElideRight
        }

        IconButton {
          id: clearGroup
          icon: "󰅖"
          sizeScale: 0.9
          onClicked: {
            for (const entry of group.modelData.entries.slice()) Notifications.dismiss(entry)
          }
        }
      }

      Repeater {
        model: ScriptModel {
          values: group.modelData.entries
        }

        NotificationCard {
          required property var modelData

          width: group.width
          entry: modelData
        }
      }
    }
  }
}
