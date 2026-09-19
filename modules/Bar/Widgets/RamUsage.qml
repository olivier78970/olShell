import QtQuick
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// RAM usage percentage; hover to see used/total in a popup.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 4

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
    }

    ThemedText {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(SystemStats.ramPercent) + "%"
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: monitorProcess.running = true
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  Process {
    id: monitorProcess
    command: Apps.systemMonitor
  }

  HoverPopup {
    id: popup
    anchorItem: root
    anchor.margins.right: -Theme.pillPadding

    ThemedText {
      text: I18n.tr("ram.used", SystemStats.formatBytes(SystemStats.ramUsedKb * 1024), SystemStats.formatBytes(SystemStats.ramTotalKb * 1024))
    }
  }
}
