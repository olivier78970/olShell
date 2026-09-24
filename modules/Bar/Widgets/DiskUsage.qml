import QtQuick
import qs.components
import qs.config
import qs.services

// How full the main disk (the one mounted on "/") is, in percent, in the
// warning color above 90%; hover to see used/total in a popup, click to open
// or close gdu on it.
Item {
  id: root

  readonly property bool nearlyFull: SystemStats.rootDiskPercent > 90

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 4

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰋊"
      color: root.nearlyFull ? Theme.warningColor : Theme.textColor
    }

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(SystemStats.rootDiskPercent) + "%"
      color: root.nearlyFull ? Theme.warningColor : Theme.textColor
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Gdu.toggle()
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  HoverPopup {
    id: popup
    anchorItem: root
    marginRight: -Theme.pillPadding

    ThemedText {
      text: SystemStats.rootDisk
        ? I18n.tr("disk.used", SystemStats.formatBytes(SystemStats.rootDisk.used), SystemStats.formatBytes(SystemStats.rootDisk.size))
        : ""
    }
  }
}
