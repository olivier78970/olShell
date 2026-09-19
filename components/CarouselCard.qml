import QtQuick
import qs.config

// One entry of a CarouselPanel: a framed card that sizes itself from the
// carousel, grows when centered, and reports clicks. Use it as the root of
// the panel's `delegate` and put the card's content inside; `modelData` and
// `index` are filled in by the carousel.
Item {
  id: root

  required property var modelData
  required property int index

  // Card height as a fraction of its width, and how much it grows while
  // centered.
  property real aspectRatio: 9 / 16
  property real selectedScale: 1.6
  // Frame background.
  property color color: Theme.borderColor

  // Attached properties only resolve on the delegate's root item, so grab
  // the view here for use by nested handlers.
  readonly property Item view: PathView.view
  readonly property bool current: root.index === root.view.currentIndex

  default property alias content: frame.data

  // Emitted when the card is clicked, after it has become the current one.
  signal activated()

  width: root.view.width / root.view.pathItemCount * 0.95
  height: width * root.aspectRatio
  scale: root.current ? root.selectedScale : 1
  z: root.current ? 1 : 0

  Behavior on scale {
    NumberAnimation { duration: 150 }
  }

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.color
    clip: true
  }

  // Drawn above the content (a child Image would otherwise cover a border
  // on `frame` itself). Every card gets the theme border; the centered one
  // is highlighted with the accent color, and at least 3px so it stands
  // out even when borders are thin or off.
  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: "transparent"
    border.color: root.current ? Theme.accentColor : Theme.outlineColor
    border.width: root.current ? Math.max(3, Theme.borderWidth) : Theme.borderWidth
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.view.currentIndex = root.index
      root.activated()
    }
  }
}
