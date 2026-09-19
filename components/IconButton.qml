import QtQuick
import qs.config

// Glyph-only button that lights up in the accent color on hover.
Item {
  id: root

  property string icon: ""
  property real sizeScale: 1.4
  signal clicked()

  implicitWidth: glyph.implicitWidth + 12
  implicitHeight: glyph.implicitHeight + 8
  opacity: enabled ? 1 : 0.4

  ThemedText {
    id: glyph
    anchors.centerIn: parent
    text: root.icon
    sizeScale: root.sizeScale
    color: mouse.containsMouse ? Theme.accentColor : Theme.textColor
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
