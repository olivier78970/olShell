import QtQuick
import qs.config

// An on/off switch: a rounded track with a knob that slides to the right and
// fills the track with the accent color while `checked`. A click emits
// `toggled`; whoever uses it decides what that changes, and `checked` follows
// from there. Dimmed and inert while not `enabled`.
Rectangle {
  id: root

  property bool checked: false
  signal toggled()

  implicitWidth: 36
  implicitHeight: 20
  radius: height / 2
  color: root.checked ? Theme.accentColor : (mouse.containsMouse && root.enabled ? Theme.borderColor : "transparent")
  border.color: root.checked ? Theme.accentColor : Theme.outlineColor
  border.width: 1
  opacity: root.enabled ? 1 : 0.35

  Behavior on color {
    ColorAnimation { duration: Theme.animationDuration }
  }

  // The knob, against the right end while on.
  Rectangle {
    width: root.height - 6
    height: width
    radius: width / 2
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
