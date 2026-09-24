import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// Popup that briefly shows the zoom factor whenever it changes (see
// services/Zoom.qml), styled like VolumeOsd. Zoomed in, it shows at the
// center of what's actually seen, on the screen the pointer is on, and
// magnified along with everything else; it follows the view while the
// pointer pans it. Zoomed out, it's at the bottom of that screen, like
// VolumeOsd. The surface covers the whole screen, with an empty input
// region so clicks pass through.
PanelWindow {
  id: root

  readonly property real factor: Zoom.factor
  // The screen the pointer is on, which is the one the zoom is seen on.
  readonly property var pointerScreen: Quickshell.screens.find(s => Zoom.cursor.x >= s.x && Zoom.cursor.x < s.x + s.width
    && Zoom.cursor.y >= s.y && Zoom.cursor.y < s.y + s.height) ?? Quickshell.screens[0] ?? null

  // Hyprland's zoom scales the screen by `factor` around the pointer, which
  // stays where it is: along each axis, the part seen starts at
  // pointer * (1 - 1/factor) and is size/factor long. Its center, in this
  // screen's coordinates:
  function seenCenter(pointer, size) {
    return pointer * (1 - 1 / root.factor) + size / (2 * root.factor)
  }

  screen: root.pointerScreen
  // Above the modal panels (on the Overlay layer too, but created before
  // this surface, which is made anew each time it shows, so it's stacked
  // over them).
  WlrLayershell.layer: WlrLayer.Overlay

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true

  color: "transparent"
  aboveWindows: true
  focusable: false
  visible: false
  mask: Region {}

  Connections {
    target: Zoom

    function onUpdated() {
      root.visible = true
      hideTimer.restart()
    }
  }

  Timer {
    id: hideTimer
    interval: 1500
    onTriggered: root.visible = false
  }

  // Moving the pointer pans the zoomed view: keep reading where it is, so
  // the popup stays at the center of what's seen.
  Timer {
    interval: 50
    repeat: true
    running: root.visible && Zoom.zoomed
    onTriggered: Zoom.readCursor()
  }

  Rectangle {
    id: pill

    readonly property real pointerX: root.screen ? Zoom.cursor.x - root.screen.x : 0
    readonly property real pointerY: root.screen ? Zoom.cursor.y - root.screen.y : 0

    implicitWidth: content.width
    implicitHeight: content.height + Theme.pillPadding
    x: Zoom.zoomed ? root.seenCenter(pill.pointerX, root.width) - pill.width / 2 : (root.width - pill.width) / 2
    y: Zoom.zoomed ? root.seenCenter(pill.pointerY, root.height) - pill.height / 2 : root.height - pill.height - 60
    radius: Theme.radiusFor(implicitHeight)
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth

    Row {
      id: content
      anchors.centerIn: parent
      spacing: 12
      leftPadding: Theme.pillPadding
      rightPadding: Theme.pillPadding
      height: 40

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: "󱡴"
        sizeScale: 1.4
      }

      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: 160
        height: 8
        radius: Theme.radiusFor(height)
        color: Theme.borderColor

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          radius: Theme.radiusFor(height)
          width: track.width * (root.factor - Zoom.minimum) / (Zoom.maximum - Zoom.minimum)
          color: Theme.accentColor

          Behavior on width {
            NumberAnimation { duration: 120 }
          }
        }
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: "×" + root.factor.toFixed(1)
      }
    }
  }
}
