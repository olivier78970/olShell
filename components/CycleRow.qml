import QtQuick
import qs.config

// A label with one value out of a list, shown between two arrows: clicking
// them (or the row's value) moves to the previous / next one. The arrows hug
// the current value, so they move as its length changes. `options` is an
// array of { value, text }; `chosen` fires with the value moved to.
Item {
  id: root

  property string label: ""
  property var options: []
  property var current: null
  property bool selected: false

  signal chosen(var value)
  signal activated()

  readonly property int currentIndex: root.options.findIndex(option => option.value === root.current)

  implicitHeight: 54

  // Moves `direction` (-1 or 1) from the current value, wrapping around.
  function move(direction) {
    if (root.options.length === 0) return
    const index = (Math.max(0, root.currentIndex) + direction + root.options.length) % root.options.length
    root.chosen(root.options[index].value)
  }

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
    spacing: 10

    CycleArrow {
      text: "‹"
      onClicked: {
        root.activated()
        root.move(-1)
      }
    }

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: root.currentIndex >= 0 ? root.options[root.currentIndex].text : ""
      color: Theme.accentColor
    }

    CycleArrow {
      text: "›"
      onClicked: {
        root.activated()
        root.move(1)
      }
    }
  }

  // One of the two arrows.
  component CycleArrow: Rectangle {
    id: arrow

    property string text: ""
    signal clicked()

    width: 30
    height: 30
    radius: Theme.radiusFor(height)
    color: mouse.containsMouse ? Theme.borderColor : "transparent"
    border.color: Theme.outlineColor
    border.width: 1

    ThemedText {
      anchors.centerIn: parent
      text: arrow.text
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: arrow.clicked()
    }
  }
}
