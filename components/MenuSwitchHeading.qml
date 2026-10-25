import QtQuick
import qs.config

// A menu's title, or the heading of a group of its entries, with an on/off
// switch at the right end of its line (like the network menu's networking
// and Wi-Fi switches). The line is only as wide as the text and the switch,
// so it never widens the menu; the switch itself goes as far right as the
// menu is wide. A click on the switch emits `toggled`.
Item {
  id: root

  property string text: ""
  // Styled as the menu's title (PopupTitle) rather than as a group's heading.
  property bool title: false
  property bool checked: false
  property bool switchEnabled: true
  signal toggled()

  // The text shown, as a title or as a heading.
  readonly property Item label: root.title ? titleText : headingText

  implicitWidth: root.label.implicitWidth + lineSwitch.width + 8
  implicitHeight: Math.max(root.label.implicitHeight, lineSwitch.height)

  PopupTitle {
    id: titleText
    visible: root.title
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    inMenu: true
  }

  PowerMenuOption {
    id: headingText
    visible: !root.title
    enabled: false
    anchors.verticalCenter: parent.verticalCenter
    label: root.text
  }

  ToggleSwitch {
    id: lineSwitch
    anchors.verticalCenter: parent.verticalCenter
    x: Math.max(root.label.implicitWidth, (root.parent?.width ?? 0) - width - 8)
    checked: root.checked
    enabled: root.switchEnabled
    onToggled: root.toggled()
  }
}
