import QtQuick
import qs.config

// The row that heads a group of bar widgets (the widgets between two
// dividers): its name on the left, then right after it (in the column of the
// widget rows' check boxes: `labelWidth` is the same for all the rows) a check
// box for whether the group is shown at all (`shown`); on the right a button
// for whether it is shown only while its pill is hovered (`hover`, lit when on;
// dimmed while the group is not shown) and two arrows moving the whole group
// earlier / later in its pill (`moved` fires with -1 or 1; dimmed when there is
// nowhere to move: `canMoveBack`, `canMoveForward`). `shownToggled` and
// `hoverToggled` fire when one is clicked. When the row is selected,
// `focusIndex` (0 the check box, 1 the button) marks the one the keyboard is on.
Item {
  id: root

  property string label: ""
  property bool shown: true
  property bool hover: false
  property real labelWidth: 0
  property string hoverText: ""
  property int focusIndex: -1
  property bool canMoveBack: false
  property bool canMoveForward: false
  property bool selected: false

  signal shownToggled()
  signal hoverToggled()
  signal moved(int steps)
  signal activated()

  // The least it needs: the name column, the check box and the buttons.
  implicitWidth: 12 + root.labelWidth + 12 + 22 + 12 + buttons.implicitWidth + 12
  implicitHeight: 38

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  ThemedText {
    id: nameLabel
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, Math.min(root.labelWidth, root.width - buttons.width - 12 - 12 - 22 - 12))
    text: root.label
    color: Theme.accentColor
    font.bold: true
    elide: Text.ElideRight
  }

  // Whether the group is shown at all.
  CheckBox {
    anchors.left: nameLabel.right
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    checked: root.shown
    focused: root.selected && root.focusIndex === 0
    hovered: shownMouse.containsMouse

    MouseArea {
      id: shownMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        root.shownToggled()
      }
    }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    ToggleButton {
      text: root.hoverText
      checked: root.hover
      focused: root.selected && root.focusIndex === 1
      dimmed: !root.shown
      onClicked: {
        root.activated()
        root.hoverToggled()
      }
    }

    // A little room between the button and the arrows.
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

  // A button that is lit (in the accent color) while `checked`.
  component ToggleButton: Rectangle {
    id: toggle

    property string text: ""
    property bool checked: false
    property bool focused: false
    property bool dimmed: false
    signal clicked()

    width: toggleLabel.implicitWidth + 20
    height: 26
    radius: Theme.radiusFor(height)
    color: toggle.checked ? Theme.accentColor : (toggleMouse.containsMouse ? Theme.borderColor : "transparent")
    border.color: toggle.focused ? Theme.textColor : (toggle.checked ? Theme.accentColor : Theme.outlineColor)
    border.width: toggle.focused ? 2 : 1
    opacity: toggle.dimmed ? 0.5 : 1

    ThemedText {
      id: toggleLabel
      anchors.centerIn: parent
      text: toggle.text
      sizeScale: 0.8
      color: toggle.checked ? Theme.backgroundColor : Theme.textColor
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: toggle.clicked()
    }
  }
}
