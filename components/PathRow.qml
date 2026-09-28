import QtQuick
import qs.config

// A label with a text field on the right, for a value typed in (a folder, a
// color). `value` is the current value, shown while not editing, after a
// dot of the color `swatch` when it is set (for a color); clicking the dot
// opens a color picker, which emits `picked` with each color picked. Clicking the field
// emits `editRequested`, and the owner sets `editing` (as it does for Enter on
// the row); Enter in the field emits `committed` with the text, Escape emits
// `cancelled`, and the owner then clears `editing`. Up/Down/Tab are kept from the owner's row
// navigation while typing.
Item {
  id: root

  property string label: ""
  property string value: ""
  property bool selected: false
  property bool editing: false
  property string swatch: ""
  // Shown, dimmed, in place of an empty value (what empty stands for).
  property string placeholder: ""

  signal committed(string text)
  signal cancelled()
  signal picked(string value)
  // Picking a color from the screen started or ended (see ColorPicker).
  signal screenPickStarted()
  signal screenPickFinished()
  signal editRequested()
  signal activated()
  // The row wants keyboard focus back to the owner (editing ended).
  signal released()

  // Where the control starts, from the row's left edge, to line it up with
  // the other rows' (the settings panel gives every row the same one); -1
  // keeps it against the right edge instead.
  property real controlX: -1
  readonly property bool aligned: root.controlX >= 0

  // The least it needs: the name and a field of some width.
  implicitWidth: (root.aligned ? root.controlX : 12 + labelText.implicitWidth + 16) + 220 + 12
  implicitHeight: 54

  onEditingChanged: {
    if (root.editing) {
      field.text = root.value
      field.forceActiveFocus()
      field.cursorPosition = field.text.length
    } else {
      field.focus = false
      root.released()
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  ThemedText {
    id: labelText
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
  }

  // The field: the value in a box, an edit cursor when editing.
  Rectangle {
    id: box
    anchors.left: root.aligned ? parent.left : labelText.right
    anchors.leftMargin: root.aligned ? root.controlX : 16
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    height: 32
    radius: Theme.radiusFor(height)
    color: "transparent"
    border.color: root.editing ? Theme.accentColor : Theme.outlineColor
    border.width: 1

    // The color the value is, before it.
    Rectangle {
      id: swatchDot
      visible: root.swatch.length > 0
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      height: 14
      radius: 7
      color: root.swatch.length > 0 ? root.swatch : "transparent"
      border.color: Theme.textColor
      border.width: 1
    }

    // Shown when not editing, cut with an ellipsis at the start if too long
    // for the box, since the end of a path is the part that matters.
    ThemedText {
      anchors.left: swatchDot.visible ? swatchDot.right : parent.left
      anchors.leftMargin: swatchDot.visible ? 8 : 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.editing
      text: root.value || root.placeholder
      color: Theme.accentColor
      opacity: root.value ? 1 : 0.55
      elide: Text.ElideLeft
    }

    TextInput {
      id: field
      anchors.left: swatchDot.visible ? swatchDot.right : parent.left
      anchors.leftMargin: swatchDot.visible ? 8 : 12
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      visible: root.editing
      clip: true
      color: Theme.textColor
      selectionColor: Theme.accentColor
      selectedTextColor: Theme.backgroundColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize()
      font.weight: Theme.fontWeight
      font.letterSpacing: Theme.fontLetterSpacing

      onAccepted: root.committed(field.text)
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
      enabled: !root.editing
      cursorShape: Qt.IBeamCursor
      onClicked: {
        root.activated()
        root.editRequested()
      }
    }

    // The dot opens the color picker instead of the text field.
    MouseArea {
      anchors.fill: swatchDot
      anchors.margins: -4
      enabled: swatchDot.visible && !root.editing
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        picker.show()
      }
    }
  }

  ColorPicker {
    id: picker
    anchorItem: swatchDot
    current: root.swatch.length > 0 ? root.swatch : "#000000"
    onPicked: value => root.picked(value)
    onScreenPickStarted: root.screenPickStarted()
    onScreenPickFinished: root.screenPickFinished()
  }
}
