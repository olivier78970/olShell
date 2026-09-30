import QtQuick
import qs.config

// A chat AI provider's row in the settings. A built-in one (Anthropic,
// OpenAI, xAI, Google) shows its name and a field for its API key; one the user added
// has fields for its name, its address and its API key, and a button taking
// it out of the list (`removed`). The key field never shows the key: only
// whether one is saved (`hasKey`), and what is typed in it is hidden.
//
// A field works like ThemeAppRow's: clicking it emits `editRequested` with
// its name ("name", "url" or "key") and the owner sets `editing` to that
// name (as it does for Enter on the row); Enter in the field emits
// `committed` with the field's name and text, Escape emits `cancelled`, and
// the owner then clears `editing`. Typing that ends any other way (`editing`
// moved or cleared) is committed too. When the row is selected, `focusIndex`
// marks what the keyboard is on, in the order of `stops`.
//
// While `asking` is set ("replace" or "remove"), the row asks instead
// whether to replace or remove the saved key (`name` is whose), with Confirm
// and Cancel
// (`answered` with 0 or 1; `focusIndex` is then on one of them).
Item {
  id: root

  property bool builtin: false
  property string name: ""
  property string url: ""
  property bool hasKey: false
  property bool selected: false
  property int focusIndex: -1
  // The field being typed in, or "" for none.
  property string editing: ""
  // What the row asks to confirm about the saved key: "replace", "remove",
  // or "" for nothing.
  property string asking: ""

  // What the keyboard can be on, in order: the fields and the remove button.
  readonly property var stops: root.builtin ? ["key"] : ["name", "url", "key", "remove"]

  signal removed()
  signal answered(int index)
  signal editRequested(string field)
  signal committed(string field, string text)
  signal cancelled()
  signal activated()
  // The row wants keyboard focus back to the owner (editing ended).
  signal released()

  // The least it needs: the name, the fields at some width and the button.
  implicitWidth: 12 + 160 + 8 + (root.builtin ? 260 : 200 + 8 + 220 + 8 + 26) + 12
  implicitHeight: 44

  // The fields and buttons, hidden while the row asks.
  readonly property bool showFields: root.asking === ""

  function focused(stop) {
    return root.selected && root.stops[root.focusIndex] === stop
  }

  // (While asking, the question's own row draws it.)
  Rectangle {
    visible: root.showFields
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  // A built-in provider's name.
  ThemedText {
    id: builtinName
    visible: root.builtin && root.showFields
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 160
    elide: Text.ElideRight
    text: root.name
  }

  ProviderField {
    id: nameField
    visible: !root.builtin && root.showFields
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 160
    field: "name"
    value: root.name
    hint: ""
  }

  ProviderField {
    id: urlField
    visible: !root.builtin && root.showFields
    anchors.left: nameField.right
    anchors.leftMargin: 8
    anchors.right: keyField.left
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    field: "url"
    value: root.url
    hint: I18n.tr("settings.chatAiProviders.url")
  }

  ProviderField {
    id: keyField
    visible: root.showFields
    anchors.left: root.builtin ? builtinName.right : undefined
    anchors.leftMargin: 8
    anchors.right: root.builtin ? parent.right : removeButton.left
    anchors.rightMargin: root.builtin ? 12 : 8
    anchors.verticalCenter: parent.verticalCenter
    width: root.builtin ? undefined : 220
    field: "key"
    secret: true
    value: ""
    hint: I18n.tr("settings.chatAiProviders.key")
  }

  // The remove button, for an added provider.
  Rectangle {
    id: removeButton
    visible: !root.builtin && root.showFields
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 26
    height: 26
    radius: Theme.radiusFor(height)
    color: removeMouse.containsMouse ? Theme.borderColor : "transparent"
    border.color: root.focused("remove") ? Theme.textColor : Theme.outlineColor
    border.width: root.focused("remove") ? 2 : 1

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

  // The question, in place of the fields while the row asks.
  DefaultsRow {
    visible: !root.showFields
    anchors.fill: parent
    label: I18n.tr(root.asking === "remove" ? "settings.chatAiProviders.confirmRemove" : "settings.chatAiProviders.confirmReplace", root.name)
    buttons: [
      { text: I18n.tr("common.confirm"), enabled: true },
      { text: I18n.tr("common.cancel"), enabled: true }
    ]
    selected: root.selected
    focusIndex: root.focusIndex
    onActivated: root.activated()
    onPressed: index => root.answered(index)
  }

  // A value in a box, typed into when `root.editing` is this field's name;
  // `hint` says what goes in it while it's empty. A `secret` one starts
  // empty and hides what is typed.
  component ProviderField: Rectangle {
    id: box

    property string field: ""
    property string value: ""
    property string hint: ""
    property bool secret: false
    readonly property bool editing: root.editing === box.field
    // Whether Enter or Escape ended the typing: any other end of it (another
    // field, row or tab, or the panel closing) keeps what was typed.
    property bool settled: false

    height: 30
    radius: Theme.radiusFor(height)
    color: "transparent"
    border.color: box.editing ? Theme.accentColor : (root.focused(box.field) ? Theme.textColor : Theme.outlineColor)
    border.width: !box.editing && root.focused(box.field) ? 2 : 1

    // Starts the typing: the keyboard goes to the field, with the value in it.
    function begin() {
      box.settled = false
      input.text = box.value
      // A tick later: the field only shows once `editing` has reached its own
      // binding, and a hidden field can't take the keyboard.
      Qt.callLater(() => {
        if (!box?.editing) return
        input.forceActiveFocus()
        input.cursorPosition = input.text.length
      })
    }

    // (A row added with its field already being typed in, as a new provider's
    // name, never sees `editing` change.)
    Component.onCompleted: if (box.editing) box.begin()

    onEditingChanged: {
      if (box.editing) {
        box.begin()
      } else {
        if (!box.settled && input.text !== box.value) root.committed(box.field, input.text)
        // Nothing of a key stays in the field.
        if (box.secret) input.text = ""
        if (input.activeFocus) {
          input.focus = false
          root.released()
        }
      }
    }

    // Shown when not editing: the value, cut with an ellipsis at the start if
    // too long, or the hint.
    ThemedText {
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      visible: !box.editing
      readonly property bool shown: box.value.length > 0 || (box.secret && root.hasKey)
      text: box.value.length > 0 ? box.value : box.hint
      color: shown ? Theme.accentColor : Theme.textColor
      opacity: shown ? 1 : 0.5
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
      echoMode: box.secret ? TextInput.Password : TextInput.Normal
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
