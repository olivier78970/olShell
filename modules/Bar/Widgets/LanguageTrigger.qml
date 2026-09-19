import QtQuick
import qs.components
import qs.config

// Shows the language in use ("EN" / "FR"); clicking it switches to the other
// one and remembers the choice.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  ThemedText {
    id: label
    anchors.centerIn: parent
    text: I18n.language.toUpperCase()
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: I18n.toggle()
  }
}
