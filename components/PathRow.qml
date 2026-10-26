import QtQuick
import qs.config

// A label with a text field on the right, for a value typed in (a folder, a
// color). `value` is the current value, shown while not editing, after a
// dot of the color `swatch` when it is set (for a color); clicking the dot
// opens a color picker, which emits `picked` with each color picked. Clicking the field
// emits `editRequested`, and the owner sets `editing` (as it does for Enter on
// the row); Enter in the field emits `committed` with the text, Escape emits
// `cancelled`, and the owner then clears `editing`. Typing that ends any other
// way (`editing` cleared) is committed too. While not `interactive` the row is
// dimmed and can't be edited; `disabledReason` then explains why in a tooltip. Up/Down/Tab are kept from the owner's row
// navigation while typing.
// With a `completionPrefix` ("webapp:"), typing text that starts with it
// opens a list of the `completions` (names) containing what follows, floating
// in `overlayHost`: Up/Down move through it, Enter or a click picks one
// (the field then holds the prefix and the name, and is committed), Tab only
// fills it in. With no completions at all, the list says `completionEmptyText`.
Item {
  id: root

  property string label: ""
  property string value: ""
  property bool selected: false
  property bool editing: false
  property string swatch: ""
  // Shown, dimmed, in place of an empty value (what empty stands for).
  property string placeholder: ""
  property bool interactive: true
  property string disabledReason: ""
  // Typed in as dots (a password); `value` should then stay empty.
  property bool secret: false
  // The completion list (see above), and where it floats (an item covering
  // the panel, above its other items).
  property string completionPrefix: ""
  property var completions: []
  property string completionEmptyText: ""
  property Item overlayHost: null

  // What the field holds as typed, kept in step with it.
  property string typed: ""
  // The completions offered for it: those containing what follows the
  // prefix (any case), the ones starting with it first; [] while the text
  // doesn't start with the prefix, or names exactly one completion.
  readonly property var matches: {
    if (!root.editing || root.completionPrefix === "" || !root.typed.toLowerCase().startsWith(root.completionPrefix.toLowerCase())) return []
    const wanted = root.typed.slice(root.completionPrefix.length).trim().toLowerCase()
    const found = root.completions.filter(name => name.toLowerCase().includes(wanted))
    if (found.length === 1 && found[0].toLowerCase() === wanted) return []
    return found.filter(name => name.toLowerCase().startsWith(wanted)).concat(found.filter(name => !name.toLowerCase().startsWith(wanted)))
  }
  // Whether the list shows: matches, or the empty text when there's nothing
  // to complete at all.
  readonly property bool completing: root.matches.length > 0
    || (root.editing && root.completionPrefix !== "" && root.completions.length === 0 && root.completionEmptyText !== ""
      && root.typed.toLowerCase().startsWith(root.completionPrefix.toLowerCase()))
  // The match Up/Down have reached.
  property int highlighted: 0
  onMatchesChanged: root.highlighted = 0

  // Puts completion `name` in the field, and commits it unless `fillOnly`.
  function complete(name, fillOnly) {
    field.text = root.completionPrefix + name
    field.cursorPosition = field.text.length
    if (!fillOnly) field.submit()
  }

  // Whether Enter or Escape ended the typing: any other end of it (another
  // row or tab, or the panel closing) keeps what was typed.
  property bool settled: false

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
      root.settled = false
      field.text = root.value
      // A tick later: the field only shows once `editing` has reached its own
      // binding, and a hidden field can't take the keyboard (the first click
      // then only showed it, and it took a second one to type).
      Qt.callLater(() => {
        if (!root?.editing) return
        field.forceActiveFocus()
        field.cursorPosition = field.text.length
      })
    } else {
      if (!root.settled && field.text !== root.value) root.committed(field.text)
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
    opacity: root.interactive ? 1 : 0.45
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
    opacity: root.interactive ? 1 : 0.45
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
      echoMode: root.secret ? TextInput.Password : TextInput.Normal
      color: Theme.textColor
      selectionColor: Theme.accentColor
      selectedTextColor: Theme.backgroundColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize()
      font.weight: Theme.fontWeight
      font.letterSpacing: Theme.fontLetterSpacing

      // Enter saves what was typed. Taken here rather than with onAccepted:
      // TextInput passes Enter on to its parent after accepting, and the
      // settings panel would take it as an Enter on the row, opening the field
      // again.
      onTextChanged: root.typed = field.text

      // Enter picks the highlighted completion while the list shows.
      Keys.onReturnPressed: event => {
        if (root.matches.length > 0) root.complete(root.matches[root.highlighted], false)
        else field.submit()
        event.accepted = true
      }
      Keys.onEnterPressed: event => {
        if (root.matches.length > 0) root.complete(root.matches[root.highlighted], false)
        else field.submit()
        event.accepted = true
      }

      function submit() {
        root.settled = true
        root.committed(field.text)
      }
      Keys.onEscapePressed: event => {
        root.settled = true
        root.cancelled()
        event.accepted = true
      }
      // Not row navigation while typing: they move through the completions.
      Keys.onUpPressed: event => {
        if (root.matches.length > 0) root.highlighted = (root.highlighted + root.matches.length - 1) % root.matches.length
        event.accepted = true
      }
      Keys.onDownPressed: event => {
        if (root.matches.length > 0) root.highlighted = (root.highlighted + 1) % root.matches.length
        event.accepted = true
      }
      Keys.onTabPressed: event => {
        if (root.matches.length > 0) root.complete(root.matches[root.highlighted], true)
        event.accepted = true
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: !root.editing && root.interactive
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
      enabled: swatchDot.visible && !root.editing && root.interactive
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        picker.show()
      }
    }
  }

  // Hover works even while the row is disabled, so the tooltip explaining why
  // still shows.
  HoverHandler {
    id: hover
  }

  DisabledTooltip {
    anchorItem: box
    text: root.disabledReason
    visible: hover.hovered && !root.interactive && root.disabledReason.length > 0
  }

  ColorPicker {
    id: picker
    anchorItem: swatchDot
    current: root.swatch.length > 0 ? root.swatch : "#000000"
    onPicked: value => root.picked(value)
    onScreenPickStarted: root.screenPickStarted()
    onScreenPickFinished: root.screenPickFinished()
  }

  // The completion list, floating above the rest of the panel just under the
  // field, as wide as it (see DropdownRow's floating list, which this copies).
  Rectangle {
    id: completionList
    visible: root.completing && root.overlayHost !== null
    z: 1
    width: box.width
    height: Math.min(Math.max(root.matches.length, 1), 6) * 30 + 8
    radius: Theme.radiusFor(30)
    color: Theme.pillColor
    border.color: Theme.accentColor
    border.width: 1

    // Moved to the host once, not bound to it: a binding moves the list back
    // into the row as the panel is torn down, which crashes the shell.
    Component.onCompleted: if (root.overlayHost) completionList.parent = root.overlayHost

    // Puts the list under the field, or above it when it would go past the
    // bottom of the host.
    function place() {
      const host = completionList.parent
      const below = box.mapToItem(host, 0, box.height)
      completionList.x = below.x
      const above = box.mapToItem(host, 0, 0).y - completionList.height
      completionList.y = below.y + completionList.height > host.height && above >= 0 ? above : below.y
    }

    // Follows the field while the list shows (the rows can scroll under it).
    Timer {
      interval: 16
      repeat: true
      running: completionList.visible
      triggeredOnStart: true
      onTriggered: completionList.place()
    }

    // Keeps clicks between the entries from reaching what's under the list.
    MouseArea {
      anchors.fill: parent
    }

    // With nothing to complete, what to do about it.
    ThemedText {
      visible: root.matches.length === 0
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: root.completionEmptyText
      elide: Text.ElideRight
      opacity: 0.55
    }

    ListView {
      id: completionView
      anchors.fill: parent
      anchors.margins: 4
      clip: true
      model: root.matches
      currentIndex: root.highlighted
      boundsBehavior: Flickable.StopAtBounds
      onCurrentIndexChanged: completionView.positionViewAtIndex(completionView.currentIndex, ListView.Contain)

      delegate: Rectangle {
        id: entry

        required property string modelData
        required property int index

        width: ListView.view.width
        height: 30
        radius: Theme.radiusFor(height)
        color: entry.index === root.highlighted ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.22) : "transparent"

        ThemedText {
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: entry.modelData
          elide: Text.ElideRight
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.highlighted = entry.index
          onClicked: root.complete(entry.modelData, false)
        }
      }
    }
  }
}
