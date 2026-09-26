import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Popup that briefly appears whenever the output volume
// or mute state changes (from the bar widget, media keys, pavucontrol...),
// where its position setting puts it (Theme.osdOffset).
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

  VolumePill {
    x: Theme.osdOffset(Theme.volumeOsdPosition, Theme.volumeOsdMargin, root.width, width, false)
    y: Theme.osdOffset(Theme.volumeOsdPosition, Theme.volumeOsdMargin, root.height, height, true)
  }
}
