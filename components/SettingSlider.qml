import QtQuick
import qs.config

// One adjustable number: its label on the left, then a slider and the
// current value on the right. The owner gives the value and reacts to
// `moved`; `activated` fires when the row is pressed (to select it).
Item {
  id: root

  property string label: ""
  property string valueText: ""
  property real from: 0
  property real to: 1
  property real stepSize: 1
  property real value: 0
  property bool selected: false

  signal moved(real value)
  signal activated()

  readonly property real fraction: root.to > root.from ? Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from))) : 0

  implicitHeight: 54

  // `raw` (anywhere between from and to) rounded to the nearest step.
  function snap(raw) {
    const steps = Math.round((raw - root.from) / root.stepSize)
    const snapped = root.from + steps * root.stepSize
    return Math.max(root.from, Math.min(root.to, Math.round(snapped * 1000) / 1000))
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
    anchors.right: track.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    elide: Text.ElideRight
  }

  ThemedText {
    id: valueLabel
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
    anchors.right: valueLabel.left
    anchors.rightMargin: 14
    anchors.verticalCenter: parent.verticalCenter
    // 35% of the row, but never so much that the label gets cut off, and at
    // least a short slider.
    width: Math.max(100, Math.min(Math.round(root.width * 0.35), root.width - labelText.implicitWidth - valueLabel.width - 12 - 12 - 14 - 12))
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

  MouseArea {
    id: area
    anchors.fill: parent
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
      // the rest of the row is just to select it.
      area.dragging = mouse.x >= track.x - 10 && mouse.x <= track.x + track.width + 10
      if (area.dragging) setFrom(mouse.x)
    }
    onPositionChanged: mouse => {
      if (pressed && area.dragging) setFrom(mouse.x)
    }
    onReleased: area.dragging = false
  }
}
