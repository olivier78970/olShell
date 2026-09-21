import QtQuick
import qs.config

// The last row of a settings category: a label and a few action buttons for
// the category's defaults. `buttons` is an array of { text, enabled }; a
// disabled one is dimmed and can't be pressed. `pressed` fires with the index
// of the button clicked. When the row is selected, `focusIndex` marks the
// button the keyboard is on.
Item {
  id: root

  property string label: ""
  property var buttons: []
  property bool selected: false
  property int focusIndex: -1

  signal pressed(int index)
  signal activated()

  // The least it needs: (some of) the name and the buttons.
  implicitWidth: 12 + Math.min(nameText.implicitWidth, 260) + 16 + buttonRow.implicitWidth + 12
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
    anchors.right: buttonRow.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    elide: Text.ElideRight
  }

  Row {
    id: buttonRow
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    Repeater {
      model: root.buttons

      Rectangle {
        id: button

        required property var modelData
        required property int index
        readonly property bool focused: root.selected && root.focusIndex === button.index

        width: label.implicitWidth + 24
        height: 30
        radius: Theme.radiusFor(height)
        color: mouse.containsMouse && button.modelData.enabled ? Theme.borderColor : "transparent"
        border.color: button.focused ? Theme.accentColor : Theme.outlineColor
        border.width: button.focused ? 2 : 1
        opacity: button.modelData.enabled ? 1 : 0.35

        ThemedText {
          id: label
          anchors.centerIn: parent
          text: button.modelData.text
          sizeScale: 0.85
          color: mouse.containsMouse && button.modelData.enabled ? Theme.accentColor : Theme.textColor
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          enabled: button.modelData.enabled
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activated()
            root.pressed(button.index)
          }
        }
      }
    }
  }
}
