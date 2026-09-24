import QtQuick
import Quickshell
import qs.config

// One adjustable number: its label on the left, then a slider and the
// current value on the right. The owner gives the value and reacts to
// `moved`; `activated` fires when the row is pressed (to select it).
//
// With `stepper`, a − button, the value in a field and a + button take the
// slider's place: the buttons move it a step (held down, repeatedly), and the
// field can be typed in, like PathRow's - a click on it emits
// `editRequested` and the owner sets `editing` (as it does for Enter on the
// row); Enter emits `committed` with the number typed, Escape `cancelled`,
// and the owner then clears `editing`.
Item {
  id: root

  property string label: ""
  property string valueText: ""
  property real from: 0
  property real to: 1
  property real stepSize: 1
  property real value: 0
  property bool selected: false
  // False for a row that can't be adjusted right now (some other setting
  // makes it have no effect); dims the row and blocks the slider, and
  // `disabledReason`, if set, explains why in a tooltip on hover.
  property bool interactive: true
  property string disabledReason: ""
  // A note about the setting, in a tooltip on hover (while the row is
  // enabled; a disabled row's `disabledReason` takes its place).
  property string tooltip: ""
  // A short, dimmed second line under the label (e.g. a related fact).
  property string note: ""
  // What the tooltip says right now, if anything.
  readonly property string tooltipText: !root.interactive && root.disabledReason.length > 0 ? root.disabledReason : root.tooltip

  // Where the control starts, from the row's left edge, to line it up with
  // the other rows' (the settings panel gives every row the same one); -1
  // keeps it against the right edge instead.
  property real controlX: -1
  readonly property bool aligned: root.controlX >= 0

  property bool stepper: false
  property bool editing: false

  signal moved(real value)
  signal activated()
  signal editRequested()
  signal committed(real value)
  signal cancelled()
  // The row wants keyboard focus back to the owner (editing ended).
  signal released()

  onEditingChanged: {
    if (root.editing) {
      field.text = String(root.value)
      field.forceActiveFocus()
      field.selectAll()
    } else {
      field.focus = false
      root.released()
    }
  }

  readonly property real fraction: root.to > root.from ? Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from))) : 0

  // The least it needs: the name, a short track and the value (or the
  // stepper's buttons and field).
  implicitWidth: root.stepper
    ? Math.max(12 + labelText.implicitWidth + 16, root.controlX) + stepperRow.implicitWidth + 12
    : (root.aligned ? root.controlX : 12 + labelText.implicitWidth + 12) + 100 + 14 + valueLabel.width + 12
  implicitHeight: 54

  // `raw` (anywhere between from and to) rounded to the nearest step.
  function snap(raw) {
    const steps = Math.round((raw - root.from) / root.stepSize)
    const snapped = root.from + steps * root.stepSize
    return Math.max(root.from, Math.min(root.to, Math.round(snapped * 1000) / 1000))
  }

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

    Column {
      anchors.left: parent.left
      anchors.leftMargin: 12
      // Up to the control: the track, a sibling, or the stepper, which isn't
      // one (it's above the row's MouseArea), so it's reached by a margin.
      anchors.right: root.stepper ? parent.right : track.left
      anchors.rightMargin: root.stepper ? root.width - stepperRow.x + 12 : 12
      anchors.verticalCenter: parent.verticalCenter

      ThemedText {
        id: labelText
        width: parent.width
        text: root.label
        elide: Text.ElideRight
      }

      ThemedText {
        visible: root.note.length > 0
        width: parent.width
        text: root.note
        sizeScale: 0.8
        opacity: 0.6
        elide: Text.ElideRight
      }
    }

    ThemedText {
      id: valueLabel
      visible: !root.stepper
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 80
      horizontalAlignment: Text.AlignRight
      text: root.valueText
      color: Theme.accentColor
    }

    // The slider itself, on the right of the row, before the value.
    Rectangle {
      id: track
      visible: !root.stepper
      anchors.right: valueLabel.left
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      // Aligned: from `controlX` to the value. Otherwise 35% of the row, but
      // never so much that the label gets cut off, and at least a short slider.
      width: root.aligned ? Math.max(100, root.width - root.controlX - valueLabel.width - 14 - 12)
        : Math.max(100, Math.min(Math.round(root.width * 0.35), root.width - labelText.implicitWidth - valueLabel.width - 12 - 12 - 14 - 12))
      height: 6
      radius: Theme.radiusFor(height)
      color: Theme.borderColor

      Rectangle {
        width: track.width * root.fraction
        height: parent.height
        radius: Theme.radiusFor(height)
        color: Theme.accentColor
      }

      Rectangle {
        x: track.width * root.fraction - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 7
        color: Theme.accentColor
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.interactive
    cursorShape: Qt.PointingHandCursor

    // True while a drag that started on the slider is going on.
    property bool dragging: false

    function setFrom(x) {
      const fraction = Math.max(0, Math.min(1, (x - track.x) / track.width))
      root.moved(root.snap(root.from + fraction * (root.to - root.from)))
    }

    onPressed: mouse => {
      root.activated()
      // Only the slider (with a little room around its knob) sets the value;
      // the rest of the row is just to select it (all of it, for a stepper,
      // whose own buttons and field are above this).
      area.dragging = !root.stepper && mouse.x >= track.x - 10 && mouse.x <= track.x + track.width + 10
      if (area.dragging) setFrom(mouse.x)
    }
    onPositionChanged: mouse => {
      if (pressed && area.dragging) setFrom(mouse.x)
    }
    onReleased: area.dragging = false
  }

  // A − / + button of the stepper; held down, it repeats.
  component StepButton: Rectangle {
    id: button

    property string symbol: ""
    property real direction: 1

    width: 32
    height: 32
    radius: Theme.radiusFor(height)
    color: buttonArea.pressed ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3)
      : buttonArea.containsMouse ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: Theme.outlineColor
    border.width: 1

    function step() {
      root.moved(root.snap(root.value + button.direction * root.stepSize))
    }

    ThemedText {
      anchors.centerIn: parent
      text: button.symbol
      color: Theme.accentColor
    }

    MouseArea {
      id: buttonArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPressed: {
        root.activated()
        // A step ends typing in the field (what was typed is dropped: the step
        // goes from the value as it was).
        if (root.editing) root.cancelled()
        button.step()
      }
      onPressAndHold: repeat.start()
      onReleased: repeat.stop()
      onCanceled: repeat.stop()
    }

    Timer {
      id: repeat
      interval: 80
      repeat: true
      onTriggered: button.step()
    }
  }

  // The stepper: − button, the value in a field, + button, against the
  // row's right edge like the check boxes and dropdowns. Above the row's own
  // MouseArea, so its buttons and field get their clicks.
  Row {
    id: stepperRow
    visible: root.stepper
    enabled: root.interactive
    opacity: root.interactive ? 1 : 0.45
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8

    StepButton {
      symbol: "−"
      direction: -1
    }

    Rectangle {
      width: 110
      height: 32
      radius: Theme.radiusFor(height)
      color: "transparent"
      border.color: root.editing ? Theme.accentColor : Theme.outlineColor
      border.width: 1

      // Shown when not editing: the value with its unit.
      ThemedText {
        anchors.centerIn: parent
        visible: !root.editing
        text: root.valueText
        color: Theme.accentColor
      }

      TextInput {
        id: field
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: root.editing
        clip: true
        horizontalAlignment: TextInput.AlignHCenter
        color: Theme.textColor
        selectionColor: Theme.accentColor
        selectedTextColor: Theme.backgroundColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize()
        font.weight: Theme.fontWeight
        font.letterSpacing: Theme.fontLetterSpacing
        // Only a number can be typed: digits, one decimal point (or comma),
        // and a minus sign only where the value can go below zero.
        validator: RegularExpressionValidator {
          regularExpression: root.from < 0 ? /-?\d*([.,]\d*)?/ : /\d*([.,]\d*)?/
        }

        // A number, with a comma accepted as the decimal point; an unfinished
        // one ("", "-", ".") leaves the value as it was.
        onAccepted: {
          const typed = parseFloat(field.text.replace(",", "."))
          if (isNaN(typed)) root.cancelled()
          else root.committed(root.snap(typed))
        }
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
    }

    StepButton {
      symbol: "+"
      direction: 1
    }
  }

  // Hover works even while the slider itself is disabled, so the tooltip
  // explaining why still shows (and over an enabled one, for `tooltip`).
  HoverHandler {
    id: hover
  }

  // A real popup window, not an item in this panel's own scene: the panel
  // (ModalPanel's `frame`) fades itself with the widget/panel opacity, and
  // anything drawn as its child fades the same way, however opaque its own
  // color is. A separate window is immune to that, so the tooltip stays
  // fully opaque no matter how translucent the panel behind it is.
  PopupWindow {
    id: tooltipPopup
    visible: hover.hovered && root.tooltipText.length > 0
    color: "transparent"
    anchor.item: root
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    implicitWidth: Math.min(280, tooltipLabel.implicitWidth + 24)
    implicitHeight: tooltipLabel.implicitHeight + 16

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      color: Theme.backgroundColor
      border.color: Theme.outlineColor
      border.width: Theme.borderWidth
    }

    ThemedText {
      id: tooltipLabel
      anchors.fill: parent
      anchors.margins: 8
      text: root.tooltipText
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
