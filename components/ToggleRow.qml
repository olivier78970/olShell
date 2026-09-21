import QtQuick
import qs.config

// A label with a row of independent on/off buttons (like bold / italic /
// underline in a text editor), or of check boxes with `checkBoxes` on.
// `options` is an array of { key, text, bold?, italic?, underline? } (the flags
// style the button's own text, as a preview; a check box without text is just
// the box); `checked` maps each key to whether it is on; `toggled` fires with
// the key of the one clicked. When the row is selected, `focusIndex` marks the
// one the keyboard is on.
Item {
  id: root

  property string label: ""
  property var options: []
  property var checked: ({})
  property bool selected: false
  property int focusIndex: -1
  property bool checkBoxes: false

  signal toggled(string key)
  signal activated()

  // The least it needs: the name and the options.
  implicitWidth: 12 + nameText.implicitWidth + 16 + optionRow.implicitWidth + 12
  implicitHeight: 54

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  ThemedText {
    id: nameText
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
  }

  Row {
    id: optionRow
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    Repeater {
      model: root.options

      Item {
        id: option

        required property var modelData
        required property int index
        readonly property bool on: root.checked[option.modelData.key] === true
        readonly property bool focused: root.selected && root.focusIndex === option.index

        width: root.checkBoxes ? box.width + (checkLabel.visible ? 8 + checkLabel.implicitWidth : 0) : button.width
        height: 30

        // As a check box, with its text beside it (if it has any).
        CheckBox {
          id: box
          visible: root.checkBoxes
          anchors.verticalCenter: parent.verticalCenter
          checked: option.on
          focused: option.focused
          hovered: mouse.containsMouse
        }

        Text {
          id: checkLabel
          visible: root.checkBoxes && (option.modelData.text ?? "") !== ""
          anchors.left: box.right
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: option.modelData.text ?? ""
          color: mouse.containsMouse ? Theme.accentColor : Theme.textColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize() * 0.85
        }

        // As a button, lit while on.
        Rectangle {
          id: button
          visible: !root.checkBoxes
          width: label.implicitWidth + 24
          height: 30
          radius: Theme.radiusFor(height)
          color: option.on ? Theme.accentColor : (mouse.containsMouse ? Theme.borderColor : "transparent")
          border.color: option.focused ? Theme.textColor : (option.on ? Theme.accentColor : Theme.outlineColor)
          border.width: option.focused ? 2 : 1

          // Not a ThemedText: the flags below are this button's own preview,
          // whatever the shell's style is.
          Text {
            id: label
            anchors.centerIn: parent
            text: option.modelData.text ?? ""
            color: option.on ? Theme.backgroundColor : Theme.textColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize() * 0.85
            font.bold: option.modelData.bold === true
            font.italic: option.modelData.italic === true
            font.underline: option.modelData.underline === true
          }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activated()
            root.toggled(option.modelData.key)
          }
        }
      }
    }
  }
}
