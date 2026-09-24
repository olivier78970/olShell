import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Look-only zoom (Settings.zoomBlocksInput): while zoomed, an invisible
// surface over every screen takes the pointer, clicks, the wheel and the
// keyboard, so the apps underneath don't react to the pointer being moved
// around to look (Hyprland's zoom still follows it). The wheel zooms in and
// out, a click or Escape zooms back out. Hyprland's own keybinds still work.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: shield

      property var modelData
      // Wheel movement not yet turned into a zoom step: a mouse wheel
      // sends 120 per notch, a touchpad many small amounts.
      property real wheelAccumulated: 0

      screen: modelData
      visible: Settings.zoomBlocksInput && Zoom.zoomed

      WlrLayershell.layer: WlrLayer.Overlay
      // Not Quickshell's default namespace: services/Blur.qml's rule would
      // otherwise blur this full-screen surface, i.e. the whole screen.
      WlrLayershell.namespace: "quickshell:zoom"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      color: "transparent"
      aboveWindows: true
      focusable: true
      exclusionMode: ExclusionMode.Ignore

      onVisibleChanged: {
        shield.wheelAccumulated = 0
        if (shield.visible) keys.forceActiveFocus()
      }

      Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
          if (event.key === Qt.Key_Escape) {
            Zoom.reset()
            event.accepted = true
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Zoom.reset()
        onWheel: wheel => {
          shield.wheelAccumulated += wheel.angleDelta.y
          while (Math.abs(shield.wheelAccumulated) >= 120) {
            const up = shield.wheelAccumulated > 0
            if (up) Zoom.zoomIn()
            else Zoom.zoomOut()
            shield.wheelAccumulated -= up ? 120 : -120
          }
        }
      }
    }
  }
}
