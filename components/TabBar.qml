import QtQuick
import qs.config

// Row of tabs with a highlighted current one. `model` is an array of
// { label, icon? }; the owner shows the page matching `currentIndex`. With
// `iconsOnly`, a tab shows its icon alone, its label in a tooltip on hover,
// and the tabs spread over the bar's whole width (give it one), the space
// between them shared out evenly.
Item {
  id: root

  property var model: []
  property int currentIndex: 0
  property bool iconsOnly: false
  // An icon-only tab's width: the same for all, room for the widest icon.
  readonly property real iconTabWidth: Math.round(Theme.fontSize() * 1.3 * 1.5) + 16

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight + 1

  Row {
    id: row
    // Icon-only: what width the tabs leave, shared between the gaps.
    spacing: root.iconsOnly && root.model.length > 1
      ? Math.max(4, (root.width - root.model.length * root.iconTabWidth) / (root.model.length - 1))
      : 4

    Repeater {
      model: root.model

      Item {
        id: tab

        required property var modelData
        required property int index
        readonly property bool current: tab.index === root.currentIndex

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
            text: tab.modelData.icon ?? ""
            color: tab.current ? Theme.accentColor : Theme.textColor
            sizeScale: root.iconsOnly ? 1.3 : 1
          }

          ThemedText {
            visible: !root.iconsOnly
            anchors.verticalCenter: parent.verticalCenter
            text: tab.modelData.label
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
          onClicked: root.currentIndex = tab.index
        }

        // The label, while it isn't shown on the tab.
        DisabledTooltip {
          anchorItem: tab
          text: tab.modelData.label
          visible: root.iconsOnly && mouse.containsMouse
        }
      }
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
