import QtQuick
import qs.config
import qs.services

// Global CPU usage percentage; hover to see per-core usage in a popup, click
// to open or close btop.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 10

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
    }

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(SystemStats.cpuPercent) + "%"
    }

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemStats.cpuFrequencyGhz.toFixed(1) + "GHz"
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Btop.toggle()
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  HoverPopup {
    id: popup
    anchorItem: root
    anchor.margins.right: -Theme.pillPadding

    Repeater {
      model: SystemStats.corePercents.length

      ThemedText {
        required property int index

        text: I18n.tr("cpu.core", index) + " : " + Math.round(SystemStats.corePercents[index]) + "%"
      }
    }
  }
}
