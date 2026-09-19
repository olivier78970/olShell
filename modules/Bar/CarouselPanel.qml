import QtQuick
import qs.config

// Picker shared by the wallpaper and theme panels: a ModalPanel holding a
// title, a carousel of `model` entries drawn with `delegate` (a Component
// whose root is a CarouselCard), and a counter. Left/Right browse, Enter or
// a click on a card emits `accepted`. Extra children (e.g. a corner button)
// are placed on the panel.
ModalPanel {
  id: root

  property string title: ""
  // Shown in place of the counter when the model is empty.
  property string emptyText: ""
  property var model: []
  property Component delegate

  // How many entries are visible on each side of the centered one.
  property int sideVisibleCount: 2

  property alias currentIndex: carousel.currentIndex
  readonly property int count: carousel.count

  // Emitted with the current index when the user confirms a choice.
  signal accepted(int index)

  maxPanelWidth: 2000
  maxPanelHeight: 650

  function accept() {
    if (carousel.count === 0 || carousel.currentIndex < 0) return
    root.accepted(carousel.currentIndex)
  }

  // Jumps (without animating) to an entry and makes it the current one.
  function showIndex(index) {
    carousel.positionViewAtIndex(index, PathView.Center)
  }

  // Arrows only browse; applying can be expensive (e.g. re-theming the
  // whole shell), so it takes an explicit Enter or click.
  onKeyPressed: event => {
    if (event.key === Qt.Key_Left) {
      carousel.decrementCurrentIndex()
      event.accepted = true
    } else if (event.key === Qt.Key_Right) {
      carousel.incrementCurrentIndex()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.accept()
      event.accepted = true
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 10

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.title
      sizeScale: 1.2
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 50

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: "‹"
        sizeScale: 2

        MouseArea {
          anchors.fill: parent
          anchors.margins: -10
          cursorShape: Qt.PointingHandCursor
          onClicked: carousel.decrementCurrentIndex()
        }
      }

      PathView {
        id: carousel
        // Panel width minus room for the two arrows and their spacing.
        width: root.panel.width - 220
        // Leaves room above and below for the title and counter rows.
        height: root.panel.height * 0.65
        model: root.model
        delegate: root.delegate
        pathItemCount: root.sideVisibleCount * 2 + 1
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange

        // Single flat plane: all cards share one straight line, one
        // size, one z-level, so raising sideVisibleCount just fits more
        // evenly-spaced cards on the path rather than layering them.
        path: Path {
          startX: 0
          startY: carousel.height / 2
          PathLine { x: carousel.width; y: carousel.height / 2 }
        }
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        sizeScale: 2

        MouseArea {
          anchors.fill: parent
          anchors.margins: -10
          cursorShape: Qt.PointingHandCursor
          onClicked: carousel.incrementCurrentIndex()
        }
      }
    }

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: carousel.count > 0 ? (carousel.currentIndex + 1) + " / " + carousel.count + "  ·  Entrée : appliquer" : root.emptyText
      sizeScale: 1.2
    }
  }
}
