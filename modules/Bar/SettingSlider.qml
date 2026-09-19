import QtQuick
import qs.config

// One adjustable number: its label and current value above a slider. The
// owner gives the value and reacts to `moved`; `activated` fires when the
// row is pressed (to select it).
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
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.top: parent.top
    anchors.topMargin: 9
    text: root.label
  }

  ThemedText {
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.top: parent.top
    anchors.topMargin: 9
    text: root.valueText
    color: Theme.accentColor
  }

  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 11
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
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor

    function setFrom(x) {
      const fraction = Math.max(0, Math.min(1, (x - track.x) / track.width))
      root.moved(root.snap(root.from + fraction * (root.to - root.from)))
    }

    onPressed: mouse => {
      root.activated()
      // Only the lower half is the slider; the label above is just to select.
      if (mouse.y > root.height / 2 - 4) setFrom(mouse.x)
    }
    onPositionChanged: mouse => {
      if (pressed && mouse.y > -20) setFrom(mouse.x)
    }
  }
}
