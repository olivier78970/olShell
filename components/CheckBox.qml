import QtQuick
import qs.config

// A small square that is filled with a check mark when `checked`. It only
// draws; whoever uses it decides what a click does (`hovered` lights it up
// while the pointer is over the area that reacts, and `focused` rings it for
// the keyboard). Dimmed while not `enabled`.
Rectangle {
  id: root

  property bool checked: false
  property bool focused: false
  property bool hovered: false

  implicitWidth: 22
  implicitHeight: 22
  radius: Theme.radiusFor(6)
  color: root.checked ? Theme.accentColor : (root.hovered && root.enabled ? Theme.borderColor : "transparent")
  border.color: root.focused ? Theme.textColor : (root.checked ? Theme.accentColor : Theme.outlineColor)
  border.width: root.focused ? 2 : 1
  opacity: root.enabled ? 1 : 0.35

  ThemedText {
    visible: root.checked
    anchors.centerIn: parent
    text: ""
    sizeScale: 0.75
    color: Theme.backgroundColor
  }
}
