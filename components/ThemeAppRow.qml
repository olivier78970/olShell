import QtQuick
import qs.config

// An app added to the themed apps in the settings, on two lines: a check box
// for whether matugen colors it (`on`; `toggled` on click), its name and a
// button taking it out of the list (`removed`); then its template file, the
// file matugen writes from it and a command run after, each in a field
// showing what goes in it while empty.
//
// A field works like SearchEngineRow's: clicking it emits `editRequested`
// with its name ("name", "template", "output" or "hook") and the owner sets
// `editing` to that name (as it does for Enter on the row); Enter in the
// field emits `committed` with the field's name and text, Escape emits
// `cancelled`, and the owner then clears `editing`. Typing that ends any
// other way (`editing` moved or cleared) is committed too. When the row is
// selected, `focusIndex` marks what the keyboard is on: 0 the check box, 1 to
// 4 the fields in that order, 5 the remove button.
Item {
  id: root

  property string name: ""
  property string template: ""
  property string output: ""
  property string hook: ""
  property bool on: true
  property bool selected: false
  property int focusIndex: -1
  // The field being typed in, or "" for none.
  property string editing: ""

  signal toggled()
  signal removed()
  signal editRequested(string field)
  signal committed(string field, string text)
  signal cancelled()
  signal activated()
  // The row wants keyboard focus back to the owner (editing ended).
  signal released()

  // The least it needs: the three fields of the second line at some width.
  implicitWidth: 12 + 3 * 180 + 2 * 8 + 12
  implicitHeight: 84

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(40)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  // The first line: on or off, the name, and the remove button.
  Item {
    id: firstLine
    anchors.top: parent.top
    anchors.topMargin: 6
    anchors.left: parent.left
    anchors.right: parent.right
    height: 34

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

    AppField {
      anchors.left: check.right
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 200
      field: "name"
      value: root.name
      hint: ""
      focusIndex: 1
    }

    // The remove button.
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 26
      height: 26
      radius: Theme.radiusFor(height)
      color: removeMouse.containsMouse ? Theme.borderColor : "transparent"
      border.color: root.selected && root.focusIndex === 5 ? Theme.textColor : Theme.outlineColor
      border.width: root.selected && root.focusIndex === 5 ? 2 : 1

      ThemedText {
        anchors.centerIn: parent
        text: "󰆴"
        sizeScale: 0.9
      }

      MouseArea {
        id: removeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.activated()
          root.removed()
        }
      }
    }
  }

  // The second line: the template, the output and the command after.
  Row {
    anchors.top: firstLine.bottom
    anchors.topMargin: 4
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 12
    spacing: 8

    readonly property real fieldWidth: (width - 2 * spacing) / 3

    AppField {
      width: parent.fieldWidth
      field: "template"
      value: root.template
      hint: I18n.tr("settings.matugenApps.template")
      focusIndex: 2
    }

    AppField {
      width: parent.fieldWidth
      field: "output"
      value: root.output
      hint: I18n.tr("settings.matugenApps.output")
      focusIndex: 3
    }

    AppField {
      width: parent.fieldWidth
      field: "hook"
      value: root.hook
      hint: I18n.tr("settings.matugenApps.hook")
      focusIndex: 4
    }
  }

  // A value in a box, typed into when `root.editing` is this field's name;
  // `hint` says what goes in it while it's empty.
  component AppField: Rectangle {
    id: box

    property string field: ""
    property string value: ""
    property string hint: ""
    property int focusIndex: 0
    readonly property bool editing: root.editing === box.field
    // Whether Enter or Escape ended the typing: any other end of it (another
    // field, row or tab, or the panel closing) keeps what was typed.
    property bool settled: false

    height: 30
    radius: Theme.radiusFor(height)
    color: "transparent"
    border.color: box.editing ? Theme.accentColor : (root.selected && root.focusIndex === box.focusIndex ? Theme.textColor : Theme.outlineColor)
    border.width: !box.editing && root.selected && root.focusIndex === box.focusIndex ? 2 : 1
    opacity: root.on || box.editing ? 1 : 0.5

    onEditingChanged: {
      if (box.editing) {
        box.settled = false
        input.text = box.value
        // A tick later: the field only shows once `editing` has reached its own
        // binding, and a hidden field can't take the keyboard (the first click
        // then only showed it, and it took a second one to type).
        Qt.callLater(() => {
          if (!box?.editing) return
          input.forceActiveFocus()
          input.cursorPosition = input.text.length
        })
      } else {
        if (!box.settled && input.text !== box.value) root.committed(box.field, input.text)
        if (input.activeFocus) {
          input.focus = false
          root.released()
        }
      }
    }

    // Shown when not editing: the value, cut with an ellipsis at the start if
    // too long (the end of a path is the part that matters), or the hint.
    ThemedText {
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      visible: !box.editing
      text: box.value.length > 0 ? box.value : box.hint
      color: box.value.length > 0 ? Theme.accentColor : Theme.textColor
      opacity: box.value.length > 0 ? 1 : 0.5
      elide: Text.ElideLeft
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

      // (A refused value leaves the field open: settled again only when
      // closed.)
      // Enter saves what was typed. Taken here rather than with onAccepted:
      // TextInput passes Enter on to its parent after accepting, and the
      // settings panel would take it as an Enter on the row, opening the field
      // again.
      Keys.onReturnPressed: event => {
        input.submit()
        event.accepted = true
      }
      Keys.onEnterPressed: event => {
        input.submit()
        event.accepted = true
      }

      function submit() {
        box.settled = true
        root.committed(box.field, input.text)
        if (box.editing) box.settled = false
      }
      Keys.onEscapePressed: event => {
        box.settled = true
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
}
