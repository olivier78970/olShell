import QtQuick
import qs.config

// Row of tabs with a highlighted current one. `model` is an array of
// { label, icon? }; the owner shows the page matching `currentIndex`.
Item {
  id: root

  property var model: []
  property int currentIndex: 0

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight + 1

  Row {
    id: row
    spacing: 4

    Repeater {
      model: root.model

      Item {
        id: tab

        required property var modelData
        required property int index
        readonly property bool current: tab.index === root.currentIndex

        width: content.implicitWidth + 24
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
          }

          ThemedText {
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
