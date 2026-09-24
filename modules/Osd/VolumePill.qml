import QtQuick
import qs.components
import qs.config
import qs.services

// The output volume as a pill: the speaker icon, a bar and the percentage.
// Shown by VolumeOsd, and on the lock screen (which covers every other
// surface, the OSD included).
Rectangle {
  id: root

  implicitWidth: content.width
  implicitHeight: content.height + Theme.pillPadding
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
        width: track.width * (Audio.muted ? 0 : Audio.volume)
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
