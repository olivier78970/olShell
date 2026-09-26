import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// The password dialog of the shell's polkit agent (services/Polkit.qml):
// shown while an application asks for administrator rights, with what it
// wants to do, who authenticates (a choice when several administrators
// can), the password field and the reason a try failed. Enter or
// "Authenticate" sends the password; Escape, "Cancel" or a click outside
// refuses the request.
ModalPanel {
  id: root

  readonly property var flow: Polkit.flow

  open: root.flow !== null
  dimmed: true
  maxPanelWidth: 480
  maxPanelHeight: content.implicitHeight + 48
  focusTarget: input

  onCloseRequested: Polkit.cancel()
  onOpened: input.text = ""

  // A new prompt (after a wrong password) starts from an empty field.
  Connections {
    target: root.flow

    function onIsResponseRequiredChanged() {
      if (root.flow.isResponseRequired) {
        input.text = ""
        input.forceActiveFocus()
      }
    }
  }

  Column {
    id: content
    anchors.centerIn: parent
    width: parent.width - 48
    spacing: 16

    // The requesting application's icon, or a shield without one.
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 48
      height: 48

      IconImage {
        id: appIcon
        anchors.fill: parent
        source: root.flow && root.flow.iconName.length > 0 ? Quickshell.iconPath(root.flow.iconName, true) : ""
        visible: status === Image.Ready
      }

      ThemedText {
        anchors.centerIn: parent
        visible: !appIcon.visible
        text: "󰒃"
        sizeScale: 2.4
        color: Theme.accentColor
      }
    }

    ThemedText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: I18n.tr("polkit.title")
      sizeScale: 1.3
    }

    ThemedText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      text: root.flow?.message ?? ""
      opacity: 0.8
    }

    // Who authenticates: named when there is only one choice, picked
    // otherwise.
    ThemedText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      visible: (root.flow?.identities.length ?? 0) === 1
      text: I18n.tr("polkit.as", root.flow?.selectedIdentity?.displayName ?? "")
      opacity: 0.6
    }

    Flow {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, implicitWidth)
      visible: (root.flow?.identities.length ?? 0) > 1
      spacing: 8

      Repeater {
        model: root.flow?.identities ?? []

        PowerMenuOption {
          required property var modelData
          icon: "󰀄"
          label: modelData.displayName
          active: modelData === root.flow?.selectedIdentity
          onClicked: Polkit.selectIdentity(modelData)
        }
      }
    }

    // The password field, like the lock screen's.
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width, 340)
      height: Theme.fontSize() + 26
      radius: Theme.radiusFor(height)
      color: Theme.pillColor
      border.color: Polkit.error.length > 0 ? Theme.warningColor : Theme.accentColor
      border.width: 2
      opacity: Polkit.checking ? 0.6 : 1

      ThemedText {
        anchors.centerIn: parent
        visible: input.text.length === 0
        text: Polkit.checking ? I18n.tr("polkit.checking")
          : (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || I18n.tr("lock.prompt")
        opacity: 0.5
      }

      TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
        passwordCharacter: "•"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize()
        color: Theme.textColor
        enabled: !Polkit.checking
        focus: true

        onAccepted: Polkit.submit(input.text)
      }
    }

    // Why the last try failed, or what polkit has to say besides the prompt.
    ThemedText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      readonly property string supplementary: root.flow?.supplementaryMessage ?? ""
      visible: text.length > 0
      text: Polkit.error.length > 0 ? Polkit.error : supplementary
      color: Polkit.error.length > 0 || root.flow?.supplementaryIsError ? Theme.warningColor : Theme.textColor
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      PowerMenuOption {
        label: I18n.tr("common.cancel")
        onClicked: Polkit.cancel()
      }

      PowerMenuOption {
        label: I18n.tr("polkit.authenticate")
        enabled: !Polkit.checking
        onClicked: Polkit.submit(input.text)
      }
    }
  }
}
