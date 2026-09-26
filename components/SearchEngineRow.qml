import QtQuick
import qs.config

// A search engine's row in the settings: a check box for whether the launcher
// offers it (`on`; `toggled` on click), its name and address in two fields,
// and on the right two arrows moving it earlier / later in the list (`moved`
// with -1 or 1; dimmed when there is nowhere to move, see `canMoveBack` and
// `canMoveForward`) and a button taking it out of the list (`removed`).
// With `browser`, it is the default browser's engine instead: `label` in
// place of the fields, and no remove button (the arrows move right into its
// place).
//
// A field works like PathRow's: clicking it emits `editRequested` with its
// name ("name" or "url") and the owner sets `editing` to that name (as it
// does for Enter on the row); Enter in the field emits `committed` with the
// field's name and text, Escape emits `cancelled`, and the owner then clears
// `editing` (or leaves it, to have a refused value typed again). When the
// row is selected, `focusIndex` marks what the keyboard is on: 0 the check
// box, 1 the name, 2 the address, 3 the remove button.
Item {
  id: root

  property bool browser: false
  property string label: ""
  property string name: ""
  property string url: ""
  property bool on: true
  property bool canMoveBack: false
  property bool canMoveForward: false
  property bool selected: false
  property int focusIndex: -1
  // The field being typed in: "name", "url" or "" for none.
  property string editing: ""

  signal toggled()
  signal moved(int steps)
  signal removed()
  signal editRequested(string field)
  signal committed(string field, string text)
  signal cancelled()
  signal activated()
  // The row wants keyboard focus back to the owner (editing ended).
  signal released()

  // The least it needs: the check box, the fields at some width and the
  // buttons.
  implicitWidth: 12 + 22 + 12 + 160 + 8 + 220 + 12 + buttons.implicitWidth + 12
  implicitHeight: 44

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  CheckBox {
    id: check
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    checked: root.on
    hovered: checkMouse.containsMouse
    focused: root.selected && root.focusIndex === 0

    MouseArea {
      id: checkMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        root.toggled()
      }
    }
  }

  // The browser's engine: what it is, instead of fields.
  ThemedText {
    visible: root.browser
    anchors.left: check.right
    anchors.leftMargin: 12
    anchors.right: buttons.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    elide: Text.ElideRight
    opacity: root.on ? 1 : 0.5
  }

  EngineField {
    id: nameField
    visible: !root.browser
    anchors.left: check.right
    anchors.leftMargin: 12
    width: 160
    field: "name"
    value: root.name
    focusIndex: 1
  }

  EngineField {
    visible: !root.browser
    anchors.left: nameField.right
    anchors.leftMargin: 8
    anchors.right: buttons.left
    anchors.rightMargin: 12
    field: "url"
    value: root.url
    focusIndex: 2
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 6

    SmallButton {
      text: "‹"
      enabled: root.canMoveBack
      onClicked: root.moved(-1)
    }

    SmallButton {
      text: "›"
      enabled: root.canMoveForward
      onClicked: root.moved(1)
    }

    // The remove button; the browser's row has none, its arrows against the
    // right edge in its place.
    SmallButton {
      visible: !root.browser
      text: "󰆴"
      focused: root.selected && root.focusIndex === 3
      onClicked: root.removed()
    }
  }

  // A value in a box, typed into when `root.editing` is this field's name.
  component EngineField: Rectangle {
    id: box

    property string field: ""
    property string value: ""
    property int focusIndex: 0
    readonly property bool editing: root.editing === box.field

    anchors.verticalCenter: parent.verticalCenter
    height: 30
    radius: Theme.radiusFor(height)
    color: box.editing ? Theme.backgroundColor : "transparent"
    border.color: box.editing ? Theme.accentColor : (root.selected && root.focusIndex === box.focusIndex ? Theme.textColor : Theme.outlineColor)
    border.width: !box.editing && root.selected && root.focusIndex === box.focusIndex ? 2 : 1
    opacity: root.on || box.editing ? 1 : 0.5

    onEditingChanged: {
      if (box.editing) {
        input.text = box.value
        input.forceActiveFocus()
        input.cursorPosition = input.text.length
      } else if (input.activeFocus) {
        input.focus = false
        root.released()
      }
    }

    // Shown when not editing, cut with an ellipsis if too long.
    ThemedText {
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      visible: !box.editing
      text: box.value
      color: Theme.accentColor
      elide: Text.ElideRight
      sizeScale: 0.85
    }

    TextInput {
      id: input
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      visible: box.editing
      clip: true
      color: Theme.textColor
      selectionColor: Theme.accentColor
      selectedTextColor: Theme.backgroundColor
      font.family: Theme.fontFamily
      font.pixelSize: Math.round(Theme.fontSize() * 0.85)
      font.weight: Theme.fontWeight
      font.letterSpacing: Theme.fontLetterSpacing

      onAccepted: root.committed(box.field, input.text)
      Keys.onEscapePressed: event => {
        root.cancelled()
        event.accepted = true
      }
      // Not row navigation while typing.
      Keys.onUpPressed: event => event.accepted = true
      Keys.onDownPressed: event => event.accepted = true
      Keys.onTabPressed: event => event.accepted = true
    }

    MouseArea {
      anchors.fill: parent
      enabled: !box.editing
      cursorShape: Qt.IBeamCursor
      onClicked: {
        root.activated()
        root.editRequested(box.field)
      }
    }
  }

  // An arrow or the remove button.
  component SmallButton: Rectangle {
    id: button

    property string text: ""
    property bool focused: false
    signal clicked()

    width: 26
    height: 26
    radius: Theme.radiusFor(height)
    color: buttonMouse.containsMouse && button.enabled ? Theme.borderColor : "transparent"
    border.color: button.focused ? Theme.textColor : Theme.outlineColor
    border.width: button.focused ? 2 : 1
    opacity: button.enabled ? 1 : 0.35

    ThemedText {
      anchors.centerIn: parent
      text: button.text
      sizeScale: 0.9
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: button.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        button.clicked()
      }
    }
  }
}
