import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Bottom-of-screen popup that briefly appears when Caps Lock or Num Lock is
// switched on or off. Same approach as VolumeOsd: the surface covers the
// whole screen with an empty input region, so clicks pass through.
PanelWindow {
  id: root

  // The key that was just toggled and its new state.
  property string key: "caps"
  property bool on: false

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true

  color: "transparent"
  aboveWindows: true
  focusable: false
  visible: false
  mask: Region {}

  Connections {
    target: LockKeys

    function onChanged(key, on) {
      root.key = key
      root.on = on
      root.visible = true
      hideTimer.restart()
    }
  }

  Timer {
    id: hideTimer
    interval: 1500
    onTriggered: root.visible = false
  }

  Rectangle {
    implicitWidth: content.width
    implicitHeight: content.height + Theme.pillPadding
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 60
    radius: Theme.radiusFor(implicitHeight)
    color: Theme.fade(Theme.pillColor, Theme.widgetOpacity)
    border.color: Theme.fade(Theme.outlineColor, Theme.borderOpaque ? 1 : Theme.widgetOpacity)
    border.width: Theme.borderWidth

    Row {
      id: content
      anchors.centerIn: parent
      spacing: 12
      leftPadding: Theme.pillPadding
      rightPadding: Theme.pillPadding
      height: 40

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        // Caps Lock / Numeric keypad glyphs from the Nerd Font.
        text: root.key === "caps" ? "󰪛" : "󰎠"
        color: root.on ? Theme.accentColor : Theme.textColor
        sizeScale: 1.4
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr(root.key === "caps" ? "lock.caps" : "lock.num")
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr(root.on ? "lock.on" : "lock.off")
        color: root.on ? Theme.accentColor : Theme.textColor
        font.bold: true
      }
    }
  }
}
