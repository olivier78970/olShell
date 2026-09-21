import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The notification center: every notification received, by application, in a
// panel where the pop-ups appear (Settings.notificationPosition), on the
// focused screen. Opening it puts the pop-ups away, as it shows them. Escape
// or a click outside closes it.
PanelWindow {
  id: root

  screen: Notifications.screen
  visible: NotificationCenterState.visible

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  color: "transparent"
  aboveWindows: true
  focusable: true
  // Covers the strip behind the bar too, so a click there closes the panel.
  exclusionMode: ExclusionMode.Ignore

  onVisibleChanged: {
    if (root.visible) {
      Notifications.hideAllPopups()
      frame.forceActiveFocus()
    }
  }

  // A notification arriving while the center is open shows in it, not as a pop-up.
  Connections {
    target: Notifications

    function onEntriesChanged() {
      if (root.visible) Notifications.hideAllPopups()
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: NotificationCenterState.visible = false
  }

  Rectangle {
    id: frame

    // What the bar reserves at the top; the panel stays out of it, and sits
    // where the pop-ups do (Settings.notificationPosition).
    readonly property real barZone: Theme.barMarginTop + Theme.barHeight + Theme.barMarginBottom
    readonly property real inset: 16

    x: Notifications.atLeft ? Theme.barMarginLeft
      : (Notifications.atRight ? root.width - width - Theme.barMarginRight : (root.width - width) / 2)
    y: Notifications.atTop ? frame.barZone + 10
      : (Notifications.atBottom ? root.height - height - 10 : frame.barZone + (root.height - frame.barZone - height) / 2)
    width: Math.min(440, root.width * 0.9)
    height: Math.min(root.height - frame.barZone - 20, frame.inset * 2 + header.height + 12 + Math.max(list.contentHeight, empty.height))
    radius: Theme.radiusFor(height)
    color: Theme.pillColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth
    opacity: Theme.widgetOpacity
    focus: true

    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        NotificationCenterState.visible = false
        event.accepted = true
      }
    }

    // Swallow clicks on the panel so they don't reach the backdrop.
    MouseArea {
      anchors.fill: parent
    }

    Row {
      id: header
      x: frame.inset
      y: frame.inset
      width: parent.width - frame.inset * 2
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
      y: frame.inset + header.height + 12
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
      x: frame.inset
      y: frame.inset + header.height + 12
      width: parent.width - frame.inset * 2
      height: parent.height - y - frame.inset
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
}
