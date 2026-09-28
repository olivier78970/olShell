import QtQuick
import qs.components
import qs.config
import qs.services

// RAM usage percentage (on a side bar, a ring filled to it around the icon);
// hover to see used/total in a popup, click to open or close btop with only
// its memory box.
Item {
  id: root

  // Whether it shows as a ring around its icon (its figures in the popup):
  // always on a side bar, and on a top or bottom bar too with its setting.
  readonly property bool ring: Theme.barVertical || Settings.ramRing

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: root.ring ? ring.implicitWidth : content.implicitWidth
  implicitHeight: root.ring ? ring.implicitHeight : content.implicitHeight

  BarStack {
    id: content
    visible: !root.ring
    anchors.centerIn: parent
    gap: 4

    BarText {
      text: "󰍛"
    }

    BarText {
      id: label
      text: Math.round(SystemStats.ramPercent) + "%"
    }
  }

  BarGauge {
    id: ring
    visible: root.ring
    anchors.centerIn: parent
    value: SystemStats.ramPercent / 100
    icon: "󰍛"
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Btop.toggle("mem")
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  HoverPopup {
    id: popup
    anchorItem: root
    marginRight: -Theme.pillPadding

    PopupTitle {
      text: I18n.tr("settings.widget.ram")
    }

    // What the bar shows, when it's a ring.
    ThemedText {
      visible: root.ring
      text: I18n.tr("stats.percentUsed", Math.round(SystemStats.ramPercent))
    }

    ThemedText {
      text: I18n.tr("ram.used", SystemStats.formatBytes(SystemStats.ramUsedKb * 1024), SystemStats.formatBytes(SystemStats.ramTotalKb * 1024))
    }
  }
}
