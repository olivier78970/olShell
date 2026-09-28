import QtQuick
import qs.components
import qs.config
import qs.services

// Magnifier icon for the screen zoom (services/Zoom.qml): the wheel over it
// zooms in and out, and a click zooms back out, as its tooltip says.
// While zoomed, the factor shows next to the icon (under it on a side bar).
Item {
  id: root

  // Wheel movement not yet turned into a zoom step: a mouse wheel sends 120
  // per notch, a touchpad or smooth-scrolling wheel many small amounts, and
  // each notch's worth is one Settings.zoomStep.
  property real wheelAccumulated: 0

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  BarStack {
    id: row
    anchors.centerIn: parent
    gap: 6

    BarText {
      text: "󱡴"
    }

    BarText {
      visible: Zoom.zoomed
      text: "×" + Zoom.factor.toFixed(1)
      sizeScale: Theme.barFigureScale
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Zoom.reset()
    onEntered: hint.hoverEntered()
    onExited: {
      root.wheelAccumulated = 0
      hint.hoverExited()
    }
    onWheel: wheel => {
      root.wheelAccumulated += wheel.angleDelta.y
      while (Math.abs(root.wheelAccumulated) >= 120) {
        const up = root.wheelAccumulated > 0
        if (up) Zoom.zoomIn()
        else Zoom.zoomOut()
        root.wheelAccumulated -= up ? 120 : -120
      }
    }
  }

  // How to use it, since nothing on it says the wheel zooms.
  HoverPopup {
    id: hint
    anchorItem: root
    alignCenter: true

    PopupTitle {
      text: I18n.tr("settings.widget.zoom")
    }

    ThemedText {
      text: I18n.tr("zoom.hint")
    }
  }
}
