import QtQuick
import qs.config

// The row that heads a group of bar widgets (the widgets between two
// dividers): its name on the left, then whether the group is shown, shown only
// while its pill is hovered, or off (`modes`, an array of { value, text },
// `mode` the current value; `modeChosen` fires with the value clicked), and two
// arrows moving the whole group earlier / later in its pill (`moved` fires
// with -1 or 1; dimmed when there is nowhere to move: `canMoveBack`,
// `canMoveForward`).
Item {
  id: root

  property string label: ""
  property var modes: []
  property string mode: ""
  property bool canMoveBack: false
  property bool canMoveForward: false
  property bool selected: false

  signal modeChosen(string value)
  signal moved(int steps)
  signal activated()

  implicitHeight: 38

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
    anchors.right: buttons.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Theme.accentColor
    font.bold: true
    elide: Text.ElideRight
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    Repeater {
      model: root.modes

      Rectangle {
        id: modeButton

        required property var modelData
        readonly property bool active: modeButton.modelData.value === root.mode

        width: modeLabel.implicitWidth + 20
        height: 26
        radius: Theme.radiusFor(height)
        color: modeButton.active ? Theme.accentColor : (modeMouse.containsMouse ? Theme.borderColor : "transparent")
        border.color: modeButton.active ? Theme.accentColor : Theme.outlineColor
        border.width: 1

        ThemedText {
          id: modeLabel
          anchors.centerIn: parent
          text: modeButton.modelData.text
          color: modeButton.active ? Theme.backgroundColor : Theme.textColor
          sizeScale: 0.8
        }

        MouseArea {
          id: modeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activated()
            root.modeChosen(modeButton.modelData.value)
          }
        }
      }
    }

    // A little room between the modes and the arrows.
    Item {
      width: 6
      height: 1
    }

    MoveArrow {
      text: "‹"
      enabled: root.canMoveBack
      onClicked: {
        root.activated()
        root.moved(-1)
      }
    }

    MoveArrow {
      text: "›"
      enabled: root.canMoveForward
      onClicked: {
        root.activated()
        root.moved(1)
      }
    }
  }

  // One of the two arrows.
  component MoveArrow: Rectangle {
    id: arrow

    property string text: ""
    signal clicked()

    width: 26
    height: 26
    radius: Theme.radiusFor(height)
    color: arrowMouse.containsMouse && arrow.enabled ? Theme.borderColor : "transparent"
    border.color: Theme.outlineColor
    border.width: 1
    opacity: arrow.enabled ? 1 : 0.35

    ThemedText {
      anchors.centerIn: parent
      text: arrow.text
    }

    MouseArea {
      id: arrowMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: arrow.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: arrow.clicked()
    }
  }
}
