import QtQuick
import Quickshell
import qs.config

// A label with a row of independent on/off buttons (like bold / italic /
// underline in a text editor), or of check boxes with `checkBoxes` on.
// `options` is an array of { key, text, bold?, italic?, underline? } (the flags
// style the button's own text, as a preview; a check box without text is just
// the box); `checked` maps each key to whether it is on; `toggled` fires with
// the key of the one clicked. When the row is selected, `focusIndex` marks the
// one the keyboard is on.
Item {
  id: root

  property string label: ""
  property var options: []
  property var checked: ({})
  property bool selected: false
  property int focusIndex: -1
  property bool checkBoxes: false
  // False for a row that can't be adjusted right now (some other setting
  // makes it have no effect); dims the row and blocks its options, and
  // `disabledReason`, if set, explains why in a tooltip on hover.
  property bool interactive: true
  property string disabledReason: ""

  signal toggled(string key)
  signal activated()

  // The least it needs: the name and the options.
  implicitWidth: 12 + nameText.implicitWidth + 16 + optionRow.implicitWidth + 12
  implicitHeight: 54

  // The row's own look, dimmed while disabled; kept out of the tooltip
  // below, which stays fully readable.
  Item {
    id: content
    anchors.fill: parent
    opacity: root.interactive ? 1 : 0.45

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
      border.color: root.selected ? Theme.accentColor : "transparent"
      border.width: 1
    }

    ThemedText {
      id: nameText
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
    }

    Row {
      id: optionRow
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Repeater {
        model: root.options

        Item {
          id: option

          required property var modelData
          required property int index
          readonly property bool on: root.checked[option.modelData.key] === true
          readonly property bool focused: root.selected && root.focusIndex === option.index

          width: root.checkBoxes ? box.width + (checkLabel.visible ? 8 + checkLabel.implicitWidth : 0) : button.width
          height: 30

          // As a check box, with its text beside it (if it has any).
          CheckBox {
            id: box
            visible: root.checkBoxes
            anchors.verticalCenter: parent.verticalCenter
            checked: option.on
            focused: option.focused
            hovered: mouse.containsMouse
          }

          Text {
            id: checkLabel
            visible: root.checkBoxes && (option.modelData.text ?? "") !== ""
            anchors.left: box.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: option.modelData.text ?? ""
            color: mouse.containsMouse ? Theme.accentColor : Theme.textColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize() * 0.85
          }

          // As a button, lit while on.
          Rectangle {
            id: button
            visible: !root.checkBoxes
            width: label.implicitWidth + 24
            height: 30
            radius: Theme.radiusFor(height)
            color: option.on ? Theme.accentColor : (mouse.containsMouse ? Theme.borderColor : "transparent")
            border.color: option.focused ? Theme.textColor : (option.on ? Theme.accentColor : Theme.outlineColor)
            border.width: option.focused ? 2 : 1

            // Not a ThemedText: the flags below are this button's own preview,
            // whatever the shell's style is.
            Text {
              id: label
              anchors.centerIn: parent
              text: option.modelData.text ?? ""
              color: option.on ? Theme.backgroundColor : Theme.textColor
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize() * 0.85
              font.bold: option.modelData.bold === true
              font.italic: option.modelData.italic === true
              font.underline: option.modelData.underline === true
            }
          }

          MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.activated()
              root.toggled(option.modelData.key)
            }
          }
        }
      }
    }
  }

  // Hover works even while the row itself is disabled, so the tooltip
  // explaining why still shows.
  HoverHandler {
    id: hover
  }

  // A real popup window, not an item in this panel's own scene: see
  // SettingSlider.qml's own tooltip for why.
  PopupWindow {
    id: tooltip
    visible: hover.hovered && !root.interactive && root.disabledReason.length > 0
    color: "transparent"
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    implicitWidth: Math.min(280, tooltipText.implicitWidth + 24)
    implicitHeight: tooltipText.implicitHeight + 16

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      color: Theme.backgroundColor
      border.color: Theme.outlineColor
      border.width: Theme.borderWidth
    }

    ThemedText {
      id: tooltipText
      anchors.fill: parent
      anchors.margins: 8
      text: root.disabledReason
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
