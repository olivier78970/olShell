import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Bottom-of-screen popup that briefly appears whenever the output volume
// or mute state changes (from the bar widget, media keys, pavucontrol...).
// The surface covers the whole screen (the pill is positioned inside it),
// but its input region is empty so clicks pass through to whatever is below.
PanelWindow {
  id: root

  readonly property real volume: Audio.volume
  readonly property bool muted: Audio.muted
  // Set true one event-loop tick after the sink becomes ready, so the
  // initial binding of volume/muted from their default 0/false to the
  // real values doesn't itself trigger a spurious OSD flash. Waiting on
  // the sink (rather than just component completion) matters because
  // Pipewire's default sink can bind after startup.
  property bool ready: false

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true

  color: "transparent"
  aboveWindows: true
  focusable: false
  visible: false
  // Empty region = no input; without it the invisible full-screen surface
  // would swallow clicks while the OSD is showing.
  mask: Region {}

  Component.onCompleted: root.armIfReady()

  Connections {
    target: Audio

    function onSinkReadyChanged() {
      root.armIfReady()
    }
  }

  function armIfReady() {
    if (Audio.sinkReady && !root.ready) Qt.callLater(() => root.ready = true)
  }

  onVolumeChanged: root.pulse()
  onMutedChanged: root.pulse()

  function pulse() {
    if (!root.ready) return
    root.visible = true
    hideTimer.restart()
  }

  Timer {
    id: hideTimer
    interval: 1500
    onTriggered: root.visible = false
  }

  Rectangle {
    id: osdRectangle
    implicitWidth : content.width  
    implicitHeight: content.height + Theme.pillPadding
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 60
    radius: Theme.radiusFor(implicitHeight)
    color: Theme.pillColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth
    opacity: Theme.widgetOpacity

    Row {
      id: content
      anchors.centerIn: parent
      spacing: 12
      leftPadding: Theme.pillPadding
      rightPadding: Theme.pillPadding
      anchors.verticalCenter: parent.verticalCenter
      height: 40

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: Audio.icon
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
          width: track.width * (root.muted ? 0 : root.volume)
          color: Theme.accentColor

          Behavior on width {
            NumberAnimation { duration: 120 }
          }
        }
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: Audio.percent + "%"
      }
    }
  }
}
