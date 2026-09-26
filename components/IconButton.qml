import QtQuick
import qs.config

// Glyph-only button that lights up in the accent color on hover.
Item {
  id: root

  property string icon: ""
  property real sizeScale: 1.4
  // The glyph's color, and on hover (the accent by default: set both on a
  // background of the accent color, where it would vanish).
  property color color: Theme.textColor
  property color hoverColor: Theme.accentColor
  // True while the pointer is over it.
  readonly property bool hovered: mouse.containsMouse
  signal clicked()

  implicitWidth: glyph.implicitWidth + 12
  implicitHeight: glyph.implicitHeight + 8
  opacity: enabled ? 1 : 0.4

  ThemedText {
    id: glyph
    anchors.centerIn: parent
    text: root.icon
    sizeScale: root.sizeScale
    color: mouse.containsMouse ? root.hoverColor : root.color
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
