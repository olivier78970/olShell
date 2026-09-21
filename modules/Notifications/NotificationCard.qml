import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.components
import qs.config
import qs.services

// One notification: its icon, summary, body and action buttons. As a pop-up
// (`toast`) it also shows how long is left before it goes away; the timer
// stops while the pointer is over it. A click runs the notification's default
// action (and puts a pop-up away, into the center); the cross closes it.
Rectangle {
  id: root

  required property var entry
  property bool toast: false

  readonly property var notification: root.entry.notification
  readonly property bool critical: root.notification.urgency === NotificationUrgency.Critical
  // Seconds the pop-up stays, 0 for never: what the sender asked for (in
  // milliseconds; 0 is never, -1 no preference), else the setting; urgent
  // notifications stay until closed.
  readonly property real timeout: {
    const asked = root.notification.expireTimeout
    if (asked > 0) return asked / 1000
    return asked === 0 || root.critical ? 0 : Settings.notificationTimeout
  }
  // What is left of the pop-up's time, from 1 down to 0.
  property real remaining: 1
  readonly property string iconSource: {
    if (root.notification.image !== "") return root.notification.image
    const icon = root.notification.appIcon
    if (icon === "") return ""
    return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true)
  }
  // The buttons: the actions but the default one, which is the click.
  readonly property var buttons: root.notification.actions.filter(action => action.identifier !== "default")

  implicitHeight: content.implicitHeight + 24
  radius: Theme.radiusFor(Math.min(height, 24))
  // A pop-up is a pill; in the center the cards are a shade lighter than the panel.
  color: root.toast ? Theme.pillColor : Qt.tint(Theme.pillColor, Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.07))
  border.color: root.critical ? Theme.warningColor : Theme.outlineColor
  border.width: Theme.borderWidth
  opacity: root.toast ? Theme.widgetOpacity : 1
  clip: true

  HoverHandler {
    id: hover
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      const acted = Notifications.activate(root.entry)
      if (root.toast) Notifications.hidePopup(root.entry)
      else if (acted) Notifications.dismiss(root.entry)
    }
  }

  Row {
    id: content
    x: 12
    y: 12
    width: parent.width - 24
    spacing: 12

    Item {
      width: 36
      height: 36

      Image {
        id: image
        anchors.fill: parent
        source: root.iconSource
        sourceSize: Qt.size(72, 72)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
      }

      ThemedText {
        anchors.centerIn: parent
        visible: !image.visible
        text: "󰂚"
        sizeScale: 1.5
        color: root.critical ? Theme.warningColor : Theme.accentColor
      }
    }

    Column {
      width: parent.width - 36 - 32 - parent.spacing * 2
      spacing: 4

      Row {
        width: parent.width
        spacing: 8

        ThemedText {
          width: parent.width - (time.visible ? time.implicitWidth + parent.spacing : 0)
          text: root.notification.summary
          font.bold: true
          elide: Text.ElideRight
          maximumLineCount: 2
          wrapMode: Text.Wrap
        }

        ThemedText {
          id: time
          text: Qt.formatTime(root.entry.time, "HH:mm")
          sizeScale: 0.7
          opacity: 0.6
          visible: !root.toast
        }
      }

      ThemedText {
        width: parent.width
        visible: text !== ""
        text: root.notification.body
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: root.toast ? 4 : 8
        elide: Text.ElideRight
        sizeScale: 0.85
        opacity: 0.85
        onLinkActivated: link => Qt.openUrlExternally(link)
      }

      Flow {
        width: parent.width
        spacing: 8
        visible: root.buttons.length > 0

        Repeater {
          model: root.buttons

          Rectangle {
            id: button
            required property var modelData

            implicitWidth: label.implicitWidth + 20
            implicitHeight: label.implicitHeight + 8
            radius: Theme.radiusFor(height)
            color: buttonMouse.containsMouse ? Theme.borderColor : "transparent"
            border.color: buttonMouse.containsMouse ? Theme.accentColor : Theme.outlineColor
            border.width: 1

            ThemedText {
              id: label
              anchors.centerIn: parent
              text: button.modelData.text
              sizeScale: 0.8
              color: buttonMouse.containsMouse ? Theme.accentColor : Theme.textColor
            }

            MouseArea {
              id: buttonMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                button.modelData.invoke()
                if (root.toast) Notifications.hidePopup(root.entry)
              }
            }
          }
        }
      }
    }

    IconButton {
      icon: "󰅖"
      sizeScale: 1
      onClicked: Notifications.dismiss(root.entry)
    }
  }

  // The time left, as a thin line along the bottom of a pop-up.
  Rectangle {
    visible: root.toast && root.timeout > 0
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    width: parent.width * root.remaining
    height: 3
    color: root.critical ? Theme.warningColor : Theme.accentColor
    opacity: 0.7
  }

  NumberAnimation on remaining {
    running: root.toast && root.timeout > 0
    paused: root.toast && root.timeout > 0 && hover.hovered
    from: 1
    to: 0
    duration: root.timeout * 1000
    onFinished: {
      Notifications.hidePopup(root.entry)
    }
  }
}
