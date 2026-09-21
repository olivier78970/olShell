import QtQuick
import qs.config

// A bar widget's row: its name on the left, then a button for the divider
// before the widget (lit when `divider` is on; `dividerToggled` on click),
// where it is on the bar as a row of buttons (`zones`, an array of
// { value, text }, `zone` the current value) and two arrows moving it earlier
// / later in its zone. `zoneChosen` fires with the value clicked and `moved`
// with -1 or 1. The arrows are dimmed when there is nowhere to move
// (`canMoveBack`, `canMoveForward`), and so is the zone button named by
// `lockedZone`, which can't be chosen (it stays, so every row lines up).
Item {
  id: root

  property string label: ""
  property var zones: []
  property string zone: ""
  property string lockedZone: ""
  property bool canMoveBack: false
  property bool canMoveForward: false
  property bool divider: false
  property bool selected: false

  signal dividerToggled()
  signal zoneChosen(string value)
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
    elide: Text.ElideRight
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    // The divider before this widget.
    Rectangle {
      width: 26
      height: 26
      radius: Theme.radiusFor(height)
      color: root.divider ? Theme.accentColor : (dividerMouse.containsMouse ? Theme.borderColor : "transparent")
      border.color: root.divider ? Theme.accentColor : Theme.outlineColor
      border.width: 1

      // The divider as the bar draws it, a thin vertical line, drawn as a
      // shape so it is centered whatever the font.
      Rectangle {
        anchors.centerIn: parent
        width: 2
        height: 14
        radius: 1
        color: root.divider ? Theme.backgroundColor : Theme.textColor
      }

      MouseArea {
        id: dividerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.activated()
          root.dividerToggled()
        }
      }
    }

    // A little room between the divider button and the zones.
    Item {
      width: 6
      height: 1
    }

    Repeater {
      model: root.zones

      Rectangle {
        id: zoneButton

        required property var modelData
        readonly property bool active: zoneButton.modelData.value === root.zone
        readonly property bool locked: zoneButton.modelData.value === root.lockedZone

        width: zoneLabel.implicitWidth + 20
        height: 26
        radius: Theme.radiusFor(height)
        color: zoneButton.active ? Theme.accentColor : (zoneMouse.containsMouse ? Theme.borderColor : "transparent")
        border.color: zoneButton.active ? Theme.accentColor : Theme.outlineColor
        border.width: 1
        opacity: zoneButton.locked ? 0.35 : 1

        ThemedText {
          id: zoneLabel
          anchors.centerIn: parent
          text: zoneButton.modelData.text
          color: zoneButton.active ? Theme.backgroundColor : Theme.textColor
          sizeScale: 0.8
        }

        MouseArea {
          id: zoneMouse
          anchors.fill: parent
          enabled: !zoneButton.locked
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activated()
            root.zoneChosen(zoneButton.modelData.value)
          }
        }
      }
    }

    // A little room between the zones and the arrows.
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
