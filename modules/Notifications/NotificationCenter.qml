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
//
// The backdrop and the frame are two separate layer-shell surfaces (see
// frameWindow below) so a blur layer rule can target just the frame - see
// ModalPanel.qml, which this mirrors.
PanelWindow {
  id: root

  screen: Notifications.screen
  visible: NotificationCenterState.visible

  WlrLayershell.layer: WlrLayer.Overlay
  // A distinct namespace from frameWindow's default one (shared with the
  // bar, pills, popups and OSDs, all of which do want to blur).
  WlrLayershell.namespace: "quickshell:backdrop"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  color: "transparent"
  aboveWindows: true
  // No keyboard focus of its own: frameWindow below takes it instead.
  focusable: false
  // Covers the strip behind the bar too, so a click there closes the panel.
  exclusionMode: ExclusionMode.Ignore

  onVisibleChanged: {
    if (root.visible) Notifications.hideAllPopups()
  }

  // A notification arriving while the center is open shows in it, not as a pop-up.
  Connections {
    target: Notifications

    function onEntriesChanged() {
      if (root.visible) Notifications.hideAllPopups()
    }
  }

  // A click actually on the frame never reaches this MouseArea to begin
  // with - it's a separate, topmost surface - but the bounds check is kept
  // as a safety net against stacking surprises.
  MouseArea {
    anchors.fill: parent
    onClicked: mouse => {
      const insidePanel = mouse.x >= frameWindow.margins.left && mouse.x <= frameWindow.margins.left + frame.width
        && mouse.y >= frameWindow.margins.top && mouse.y <= frameWindow.margins.top + frame.height
      if (!insidePanel) NotificationCenterState.visible = false
    }
  }

  // The actual panel, its own layer-shell surface on Quickshell's default
  // namespace (like the bar, pills, popups and OSDs, see services/Blur.qml)
  // rather than root's: Hyprland blurs whatever's behind a whole surface,
  // and the frame used to share the backdrop's, which meant the dim blurred
  // too instead of staying sharp. Positioned with explicit margins (rather
  // than left unanchored) so its on-screen geometry is known here, for the
  // bounds check above.
  PanelWindow {
    id: frameWindow

    visible: root.visible
    screen: root.screen

    WlrLayershell.layer: WlrLayer.Overlay
    // Grabs all keyboard input while open, so shortcuts/typing never leak
    // to whatever's behind the panel.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
      top: true
      left: true
    }
    // What the bar reserves at the top; the panel stays out of it, and sits
    // where the pop-ups do (Settings.notificationPosition). Pulled up into
    // that zone by the border width so its border overlaps the bar's
    // instead of doubling up with it, the same as the bar's own popups.
    readonly property real barZone: Theme.barMarginTop + Theme.barHeight + Theme.barMarginBottom
    margins.left: Notifications.atLeft ? Theme.barMarginLeft
      : (Notifications.atRight ? root.width - frame.width - Theme.barMarginRight : (root.width - frame.width) / 2)
    margins.top: Notifications.atTop ? frameWindow.barZone - Theme.borderWidth
      : (Notifications.atBottom ? root.height - frame.height - 10 : frameWindow.barZone + (root.height - frameWindow.barZone - frame.height) / 2)
    implicitWidth: frame.width
    implicitHeight: frame.height

    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    // Grabbed here, from this window's own visibility, rather than root's:
    // frameWindow's `visible` only mirrors root's a binding tick later, so
    // requesting focus from root's own visibleChanged could fire before
    // this window (and its surface) actually exists yet to grab it.
    onVisibleChanged: {
      if (frameWindow.visible) frame.forceActiveFocus()
    }

    Rectangle {
      id: frame

      readonly property real inset: 16

      width: Math.min(440, root.width * 0.9)
      height: Math.min(root.height - frameWindow.barZone - 20, frame.inset * 2 + header.height + 12 + Math.max(list.contentHeight, empty.height))
      radius: Theme.radiusFor(height)
      color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
      border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
      border.width: Theme.borderWidth
      focus: true

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          NotificationCenterState.visible = false
          event.accepted = true
        }
      }

      // Content never fades with the widget opacity, only the frame's fill and
      // border do; kept as a separate item from `frame` so it doesn't inherit
      // theirs.
      Item {
        id: contentHolder
        anchors.fill: parent

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
  }
}
