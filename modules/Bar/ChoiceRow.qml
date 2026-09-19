import QtQuick
import qs.config

// A label with a row of options, the current one highlighted. `options` is
// an array of { value, text }; `chosen` fires with the value clicked.
Item {
  id: root

  property string label: ""
  property var options: []
  property var current: null
  property bool selected: false

  signal chosen(var value)
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
        id: option

        required property var modelData
        readonly property bool active: option.modelData.value === root.current

        width: label.implicitWidth + 24
        height: 30
        radius: Theme.radiusFor(height)
        color: option.active ? Theme.accentColor : (mouse.containsMouse ? Theme.borderColor : "transparent")
        border.color: option.active ? Theme.accentColor : Theme.outlineColor
        border.width: 1

        ThemedText {
          id: label
          anchors.centerIn: parent
          text: option.modelData.text
          color: option.active ? Theme.backgroundColor : Theme.textColor
          sizeScale: 0.85
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activated()
            root.chosen(option.modelData.value)
          }
        }
      }
    }
  }
}
