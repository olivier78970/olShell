import QtQuick
import qs.config

// A label with a row of options, the current one highlighted. `options` is
// an array of { value, text, capitalization?, swatch? } (`swatch`, a color,
// is drawn as a dot before the text, or alone for an empty text); `chosen`
// fires with the value
// clicked. With `literal` on, the buttons show their text as written (or in
// the capitalization the option names) instead of the shell's, for a row that
// lets you choose that capitalization.
Item {
  id: root

  property string label: ""
  property var options: []
  property var current: null
  property bool selected: false
  property bool literal: false
  // False for a row that can't be adjusted right now (some other setting
  // makes it have no effect); dims the row and blocks its options, and
  // `disabledReason`, if set, explains why in a tooltip on hover.
  property bool interactive: true
  property string disabledReason: ""

  signal chosen(var value)
  signal activated()

  // Where the settings panel's column of controls starts (-1: none). The
  // control here stays against the right edge; the row just asks to be at
  // least as wide as it would be with the control lined up in that column,
  // so the panel is as wide as a page lined up that way.
  property real controlX: -1

  // The least it needs: the name and the buttons.
  implicitWidth: Math.max(12 + nameText.implicitWidth + 16, root.controlX) + optionRow.implicitWidth + 12
  implicitHeight: 54

  // The row's own look, dimmed while disabled; kept out of the tooltip
  // below, which stays fully readable.
  Item {
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

        Rectangle {
          id: option

          required property var modelData
          readonly property bool active: option.modelData.value === root.current

          width: optionContent.implicitWidth + 24
          height: 30
          radius: Theme.radiusFor(height)
          color: option.active ? Theme.accentColor : (mouse.containsMouse ? Theme.borderColor : "transparent")
          border.color: option.active ? Theme.accentColor : Theme.outlineColor
          border.width: 1

          Row {
            id: optionContent
            anchors.centerIn: parent
            spacing: 8

            // The color the option stands for, ringed so it shows on the
            // button's own color too.
            Rectangle {
              visible: option.modelData.swatch !== undefined
              anchors.verticalCenter: parent.verticalCenter
              width: 14
              height: 14
              radius: 7
              color: option.modelData.swatch ?? "transparent"
              border.color: option.active ? Theme.backgroundColor : Theme.textColor
              border.width: 1
            }

            ThemedText {
              id: label
              visible: text.length > 0
              anchors.verticalCenter: parent.verticalCenter
              text: option.modelData.text
              color: option.active ? Theme.backgroundColor : Theme.textColor
              sizeScale: 0.85
              font.capitalization: root.literal ? (option.modelData.capitalization ?? Font.MixedCase) : Theme.fontCapitalization
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
              root.chosen(option.modelData.value)
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

  DisabledTooltip {
    anchorItem: root
    text: root.disabledReason
    visible: hover.hovered && !root.interactive && root.disabledReason.length > 0
  }
}
