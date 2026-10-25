import QtQuick
import qs.config

// An on/off switch: a track, rounded as the theme's radius setting says, with
// a knob that slides to the right and fills the track with the accent color
// while `checked`. A click emits `toggled`; whoever uses it decides what that
// changes, and `checked` follows from there. Dimmed and inert while not
// `enabled`.
Rectangle {
  id: root

  property bool checked: false
  signal toggled()

  implicitWidth: 36
  implicitHeight: 20
  radius: Theme.radiusFor(height)
  color: root.checked ? Theme.accentColor : (mouse.containsMouse && root.enabled ? Theme.borderColor : "transparent")
  border.color: root.checked ? Theme.accentColor : Theme.outlineColor
  border.width: 1
  opacity: root.enabled ? 1 : 0.35

  Behavior on color {
    ColorAnimation { duration: Theme.animationDuration }
  }

  // The knob, against the right end while on, its corners following the
  // track's (inset by the gap around it).
  Rectangle {
    width: root.height - 6
    height: width
    radius: Math.max(0, root.radius - 3)
    anchors.verticalCenter: parent.verticalCenter
    x: root.checked ? root.width - width - 3 : 3
    color: root.checked ? Theme.backgroundColor : Theme.textColor

    Behavior on x {
      NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
