import QtQuick
import qs.config

// Row of tabs with a highlighted current one. `model` is an array of
// { label, icon? }; the owner shows the page matching `currentIndex`. With
// `iconsOnly`, a tab shows its icon alone, its label in a tooltip on hover,
// and the tabs spread over the bar's whole width (give it one), the space
// between them shared out evenly. With `maxVisible` set below the number of
// tabs, only that many show (a window that moves to keep the current one in
// view), between two buttons that switch to the previous / next tab, round
// to the other end.
Item {
  id: root

  property var model: []
  property int currentIndex: 0
  property bool iconsOnly: false
  // The most tabs shown at once (0 for all of them).
  property int maxVisible: 0
  // The first tab shown, and how many are.
  property int first: 0
  readonly property int count: root.maxVisible > 0 ? Math.min(root.maxVisible, root.model.length) : root.model.length
  readonly property bool paged: root.count < root.model.length
  // An icon-only tab's width: the same for all, room for the widest icon.
  readonly property real iconTabWidth: Math.round(Theme.fontSize() * 1.3 * 1.5) + 16

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight + 1

  // Moves the window of tabs to have the current one in it.
  function reveal() {
    const last = Math.max(0, root.model.length - root.count)
    let start = root.first
    if (root.currentIndex < start) start = root.currentIndex
    else if (root.currentIndex >= start + root.count) start = root.currentIndex - root.count + 1
    root.first = Math.max(0, Math.min(start, last))
  }

  onCurrentIndexChanged: root.reveal()
  onCountChanged: root.reveal()
  Component.onCompleted: root.reveal()

  // Switches to the tab `step` further, round to the other end.
  function cycle(step) {
    root.currentIndex = (root.currentIndex + step + root.model.length) % root.model.length
  }

  // A button of the cycling pair.
  component CycleButton: Item {
    id: button

    property string glyph
    property int step

    visible: root.paged
    width: root.paged ? content.implicitHeight + 14 : 0
    height: content.implicitHeight + 14

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      color: buttonMouse.containsMouse ? Theme.borderColor : "transparent"
    }

    ThemedText {
      id: content
      anchors.centerIn: parent
      text: button.glyph
    }

    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.cycle(button.step)
    }
  }

  Row {
    id: row
    // Icon-only: what width the tabs leave, shared between the gaps.
    spacing: root.iconsOnly && root.model.length > 1
      ? Math.max(4, (root.width - root.model.length * root.iconTabWidth) / (root.model.length - 1))
      : 4

    CycleButton {
      glyph: "󰅁"
      step: -1
    }

    Repeater {
      model: Array.from({ length: root.count }, (_, offset) => root.first + offset)

      Item {
        id: tab

        required property int modelData
        // The tab's place in the whole list, and its entry.
        readonly property int position: tab.modelData
        readonly property var entry: root.model[tab.modelData] ?? ({ label: "" })
        readonly property bool current: tab.position === root.currentIndex

        width: root.iconsOnly ? root.iconTabWidth : content.implicitWidth + 24
        height: content.implicitHeight + 14

        Rectangle {
          anchors.fill: parent
          radius: Theme.radiusFor(height)
          color: mouse.containsMouse && !tab.current ? Theme.borderColor : "transparent"
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: 6

          ThemedText {
            visible: text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: tab.entry.icon ?? ""
            color: tab.current ? Theme.accentColor : Theme.textColor
            sizeScale: root.iconsOnly ? 1.3 : 1
          }

          ThemedText {
            visible: !root.iconsOnly
            anchors.verticalCenter: parent.verticalCenter
            text: tab.entry.label
            color: tab.current ? Theme.accentColor : Theme.textColor
          }
        }

        // Underline marking the current tab.
        Rectangle {
          visible: tab.current
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 2
          color: Theme.accentColor
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.currentIndex = tab.position
        }

        // The label, while it isn't shown on the tab.
        DisabledTooltip {
          anchorItem: tab
          text: tab.entry.label
          visible: root.iconsOnly && mouse.containsMouse
        }
      }
    }

    CycleButton {
      glyph: "󰅂"
      step: 1
    }
  }

  // Baseline under the whole bar.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Theme.separatorColor
  }
}
