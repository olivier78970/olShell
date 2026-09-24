import QtQuick
import Quickshell.Io
import qs.components
import qs.config

// The notification actions (config/NotificationActions.qml): commands run when
// a notification arrives, by what it says. A list of them - each switched on
// or off, edited or removed - and a form to add or edit one. Opened from the
// settings panel, from a notification in the notification center (straight on
// a new rule filled in from it), or from outside via:
//   quickshell -p . ipc call notificationActions toggle
// Escape leaves the form for the list, then closes.
ModalPanel {
  id: root

  // Whether the form is shown (not the list), and the index of the rule in it
  // (-1: a new one); its `enabled` is kept as it was.
  property bool editing: false
  property int editIndex: -1
  property bool editEnabled: true

  readonly property var modeLabels: ({
    contains: I18n.tr("notificationActions.mode.contains"),
    starts: I18n.tr("notificationActions.mode.starts"),
    is: I18n.tr("notificationActions.mode.is")
  })

  maxPanelWidth: 760
  maxPanelHeight: 640
  focusTarget: root.editing ? appField.input : root.panel

  open: NotificationActionsState.visible
  onCloseRequested: NotificationActionsState.close()
  onOpened: {
    if (NotificationActionsState.draft) root.edit(-1, NotificationActionsState.draft)
    else root.editing = false
  }

  onKeyPressed: event => {
    // Escape in the form: back to the list, not closed.
    if (event.key === Qt.Key_Escape && root.editing) {
      root.editing = false
      root.panel.forceActiveFocus()
      event.accepted = true
    }
  }

  IpcHandler {
    target: "notificationActions"

    function toggle(): void {
      NotificationActionsState.toggle()
    }
  }

  // Opens the form on rule `index` (-1: a new one), with `fields` in it.
  function edit(index, fields) {
    const rule = NotificationActions.clean(fields ?? {})
    root.editIndex = index
    root.editEnabled = rule.enabled
    appField.load(rule.app, rule.appMode)
    summaryField.load(rule.summary, rule.summaryMode)
    bodyField.load(rule.body, rule.bodyMode)
    commandBox.input.text = rule.command
    silentBox.checked = rule.silent
    root.editing = true
    Qt.callLater(() => (rule.command === "" && rule.app !== "" ? commandBox.input : appField.input).forceActiveFocus())
  }

  function saveForm() {
    NotificationActions.save({
      app: appField.text,
      appMode: appField.mode,
      summary: summaryField.text,
      summaryMode: summaryField.mode,
      body: bodyField.text,
      bodyMode: bodyField.mode,
      command: commandBox.input.text.trim(),
      silent: silentBox.checked,
      enabled: root.editEnabled
    }, root.editIndex)
    root.editing = false
    root.panel.forceActiveFocus()
  }

  // What a rule matches, in a line: "App is "blueman" · Title contains ...".
  function describe(rule) {
    const parts = []
    const part = (field, value, mode) => {
      if (value !== "") parts.push(I18n.tr("notificationActions.field." + field) + " " + root.modeLabels[mode] + " « " + value + " »")
    }
    part("app", rule.app, rule.appMode)
    part("summary", rule.summary, rule.summaryMode)
    part("body", rule.body, rule.bodyMode)
    return parts.length > 0 ? parts.join("  ·  ") : I18n.tr("notificationActions.any")
  }

  // A condition of the form: its name, how it compares (contains / starts
  // with / is) and the text it compares with. Filled in by load().
  component ConditionField: Row {
    id: field

    property string label: ""
    property string mode: "contains"
    property string placeholder: ""
    readonly property string text: box.input.text
    readonly property Item input: box.input

    function load(text, mode) {
      box.input.text = text
      field.mode = mode
    }

    width: parent.width
    spacing: 10

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      width: 90
      text: field.label
      elide: Text.ElideRight
    }

    Row {
      id: modeButtons
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Repeater {
        model: NotificationActions.modes

        Rectangle {
          required property string modelData
          readonly property bool chosen: field.mode === modelData

          width: modeText.implicitWidth + 16
          height: 30
          radius: Theme.radiusFor(height)
          color: chosen ? Theme.accentColor : "transparent"
          border.color: chosen ? Theme.accentColor : Theme.outlineColor
          border.width: 1

          ThemedText {
            id: modeText
            anchors.centerIn: parent
            text: root.modeLabels[parent.modelData]
            sizeScale: 0.8
            color: parent.chosen ? Theme.backgroundColor : Theme.textColor
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: field.mode = parent.modelData
          }
        }
      }
    }

    TextBox {
      id: box
      anchors.verticalCenter: parent.verticalCenter
      width: field.width - 90 - modeButtons.width - field.spacing * 2
      placeholder: field.placeholder
    }
  }

  // A text field, in a box.
  component TextBox: Rectangle {
    id: textBox

    property string placeholder: ""
    readonly property Item input: textInput

    height: 34
    radius: Theme.radiusFor(height)
    color: "transparent"
    border.color: textInput.activeFocus ? Theme.accentColor : Theme.outlineColor
    border.width: 1

    TextInput {
      id: textInput
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      clip: true
      color: Theme.textColor
      selectionColor: Theme.accentColor
      selectedTextColor: Theme.backgroundColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize()
      font.weight: Theme.fontWeight
      // Enter saves (when there's a command to run).
      onAccepted: if (commandBox.input.text.trim().length > 0) root.saveForm()

      ThemedText {
        visible: textInput.text.length === 0
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        elide: Text.ElideRight
        text: textBox.placeholder
        opacity: 0.45
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.IBeamCursor
      onPressed: mouse => {
        textInput.forceActiveFocus()
        mouse.accepted = false
      }
    }
  }

  // A text button (Add, Save, Cancel...).
  component TextButton: Rectangle {
    id: button

    property string text: ""
    property bool primary: false

    signal clicked()

    width: label.implicitWidth + 28
    height: 34
    radius: Theme.radiusFor(height)
    color: button.primary ? Theme.accentColor : (area.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent")
    border.color: button.primary ? Theme.accentColor : Theme.outlineColor
    border.width: 1
    opacity: enabled ? 1 : 0.45

    ThemedText {
      id: label
      anchors.centerIn: parent
      text: button.text
      color: button.primary ? Theme.backgroundColor : Theme.textColor
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 14

    ThemedText {
      id: title
      text: root.editing ? I18n.tr(root.editIndex < 0 ? "notificationActions.new" : "notificationActions.edit") : I18n.tr("notificationActions.title")
      sizeScale: 1.2
      font.bold: true
    }

    // ---- The list ----
    Item {
      visible: !root.editing
      width: parent.width
      height: parent.height - title.height - parent.spacing

      ThemedText {
        id: intro
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("notificationActions.intro")
        opacity: 0.7
        sizeScale: 0.85
      }

      ListView {
        id: list
        anchors.top: intro.bottom
        anchors.topMargin: 12
        anchors.bottom: addButton.top
        anchors.bottomMargin: 12
        width: parent.width
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: NotificationActions.rules

        delegate: Rectangle {
          id: ruleRow

          required property var modelData
          required property int index

          width: list.width
          height: ruleText.implicitHeight + 20
          radius: Theme.radiusFor(Math.min(height, 40))
          color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.05)

          CheckBox {
            id: enabledBox
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            checked: ruleRow.modelData.enabled

            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: NotificationActions.setEnabled(ruleRow.index, !ruleRow.modelData.enabled)
            }
          }

          Column {
            id: ruleText
            anchors.left: enabledBox.right
            anchors.leftMargin: 12
            anchors.right: buttons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            opacity: ruleRow.modelData.enabled ? 1 : 0.5

            ThemedText {
              width: parent.width
              wrapMode: Text.Wrap
              text: root.describe(ruleRow.modelData)
              sizeScale: 0.85
            }

            ThemedText {
              width: parent.width
              elide: Text.ElideRight
              text: "→ " + (ruleRow.modelData.command || I18n.tr("notificationActions.noCommand")) + (ruleRow.modelData.silent ? "   " + I18n.tr("notificationActions.silentTag") : "")
              color: Theme.accentColor
            }
          }

          Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            IconButton {
              icon: "󰏫"
              sizeScale: 1.1
              onClicked: root.edit(ruleRow.index, ruleRow.modelData)
            }

            IconButton {
              icon: "󰆴"
              sizeScale: 1.1
              onClicked: NotificationActions.remove(ruleRow.index)
            }
          }
        }

        ThemedText {
          visible: list.count === 0
          anchors.centerIn: parent
          text: I18n.tr("notificationActions.empty")
          opacity: 0.6
        }
      }

      TextButton {
        id: addButton
        anchors.bottom: parent.bottom
        text: "+  " + I18n.tr("notificationActions.add")
        primary: true
        onClicked: root.edit(-1, {})
      }
    }

    // ---- The form ----
    Column {
      visible: root.editing
      width: parent.width
      spacing: 12

      ThemedText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("notificationActions.formIntro")
        opacity: 0.7
        sizeScale: 0.85
      }

      ConditionField {
        id: appField
        label: I18n.tr("notificationActions.field.app")
        placeholder: I18n.tr("notificationActions.anyValue")
      }

      ConditionField {
        id: summaryField
        label: I18n.tr("notificationActions.field.summary")
        placeholder: I18n.tr("notificationActions.anyValue")
      }

      ConditionField {
        id: bodyField
        label: I18n.tr("notificationActions.field.body")
        placeholder: I18n.tr("notificationActions.anyValue")
      }

      Row {
        width: parent.width
        spacing: 10

        ThemedText {
          anchors.verticalCenter: parent.verticalCenter
          width: 90
          text: I18n.tr("notificationActions.field.command")
        }

        TextBox {
          id: commandBox
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 90 - parent.spacing
          placeholder: I18n.tr("notificationActions.commandPlaceholder")
        }
      }

      ThemedText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("notificationActions.commandHint")
        opacity: 0.55
        sizeScale: 0.8
      }

      Row {
        spacing: 10

        CheckBox {
          id: silentBox
          anchors.verticalCenter: parent.verticalCenter

          MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: silentBox.checked = !silentBox.checked
          }
        }

        ThemedText {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("notificationActions.silent")

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: silentBox.checked = !silentBox.checked
          }
        }
      }

      Row {
        spacing: 10

        TextButton {
          text: I18n.tr("notificationActions.save")
          primary: true
          enabled: commandBox.input.text.trim().length > 0
          onClicked: root.saveForm()
        }

        TextButton {
          text: I18n.tr("notificationActions.cancel")
          onClicked: {
            root.editing = false
            root.panel.forceActiveFocus()
          }
        }
      }
    }
  }
}
