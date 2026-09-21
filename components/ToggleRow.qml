import QtQuick
import qs.config

// A label with a row of independent on/off buttons (like bold / italic /
// underline in a text editor). `options` is an array of { key, text, bold?,
// italic?, underline? } (the flags style the button's own text, as a
// preview); `checked` maps each key to whether it is on; `toggled` fires with
// the key of the button clicked. When the row is selected, `focusIndex` marks
// the button the keyboard is on.
Item {
  id: root

  property string label: ""
  property var options: []
  property var checked: ({})
  property bool selected: false
  property int focusIndex: -1

  signal toggled(string key)
  signal activated()

  implicitHeight: 54

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  ThemedText {
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    Repeater {
      model: root.options

      Rectangle {
        id: button

        required property var modelData
        required property int index
        readonly property bool on: root.checked[button.modelData.key] === true

        width: label.implicitWidth + 24
        height: 30
        radius: Theme.radiusFor(height)
        color: button.on ? Theme.accentColor : (mouse.containsMouse ? Theme.borderColor : "transparent")
        border.color: root.selected && root.focusIndex === button.index ? Theme.textColor : (button.on ? Theme.accentColor : Theme.outlineColor)
        border.width: root.selected && root.focusIndex === button.index ? 2 : 1

        // Not a ThemedText: the flags below are this button's own preview,
        // whatever the shell's style is.
        Text {
          id: label
          anchors.centerIn: parent
          text: button.modelData.text
          color: button.on ? Theme.backgroundColor : Theme.textColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize() * 0.85
          font.bold: button.modelData.bold === true
          font.italic: button.modelData.italic === true
          font.underline: button.modelData.underline === true
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activated()
            root.toggled(button.modelData.key)
          }
        }
      }
    }
  }
}
