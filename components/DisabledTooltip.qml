import QtQuick
import Quickshell
import qs.config

// The tooltip a disabled settings row shows on hover to say why it can't be
// adjusted, under `anchorItem` (also used as a plain text tooltip: the chat
// AI panel's access icons, the launcher's tabs). A real popup window, not an item in the
// panel's own scene: see SettingSlider.qml's own tooltip for why.
PopupWindow {
  id: root

  property Item anchorItem: null
  property string text: ""

  color: "transparent"
  anchor.item: root.anchorItem
  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom
  anchor.margins.top: 6
  implicitWidth: Math.min(280, tooltipText.implicitWidth + 24)
  implicitHeight: tooltipText.implicitHeight + 16

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: Theme.backgroundColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth
  }

  ThemedText {
    id: tooltipText
    anchors.fill: parent
    anchors.margins: 8
    text: root.text
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
  }
}
