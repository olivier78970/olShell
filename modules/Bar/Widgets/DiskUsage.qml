import QtQuick
import qs.components
import qs.config
import qs.services

// How full the main disk (the one mounted on "/") is, in percent (on a side
// bar, a ring filled to it around the icon), in the warning color above 90%;
// hover to see used/total in a popup, click to run its
// action (Settings.diskAction).
Item {
  id: root

  // Whether it shows as a ring around its icon (its figures in the popup): with
  // the vertical layout (Settings.diskLayout), and with the automatic one on a
  // side bar.
  readonly property bool ring: Settings.diskLayout === "vertical" || (Settings.diskLayout === "auto" && Theme.barVertical)

  readonly property bool nearlyFull: SystemStats.rootDiskPercent > 90

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: root.ring ? ring.implicitWidth : content.implicitWidth
  implicitHeight: root.ring ? ring.implicitHeight : content.implicitHeight

  BarStack {
    id: content
    visible: !root.ring
    anchors.centerIn: parent
    gap: 4

    BarText {
      text: "󰋊"
      color: root.nearlyFull ? Theme.warningColor : Theme.textColor
    }

    BarText {
      text: Math.round(SystemStats.rootDiskPercent) + "%"
      color: root.nearlyFull ? Theme.warningColor : Theme.textColor
    }
  }

  // On a side bar: a ring filled to how full it is, in the warning color too.
  BarGauge {
    id: ring
    visible: root.ring
    anchors.centerIn: parent
    value: SystemStats.rootDiskPercent / 100
    icon: "󰋊"
    color: root.nearlyFull ? Theme.warningColor : Theme.accentColor
    iconColor: root.nearlyFull ? Theme.warningColor : Theme.textColor
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      popup.dismiss()
      WidgetActions.run("disk")
    }
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  HoverPopup {
    id: popup
    anchorItem: root
    marginRight: -Theme.pillPadding

    PopupTitle {
      text: I18n.tr("perf.storage")
    }

    // What the bar shows, when it's a ring.
    ThemedText {
      visible: root.ring
      text: I18n.tr("stats.percentUsed", Math.round(SystemStats.rootDiskPercent))
    }

    ThemedText {
      text: SystemStats.rootDisk
        ? I18n.tr("disk.used", SystemStats.formatBytes(SystemStats.rootDisk.used), SystemStats.formatBytes(SystemStats.rootDisk.size))
        : ""
    }
  }
}
