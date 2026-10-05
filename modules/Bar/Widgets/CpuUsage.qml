import QtQuick
import qs.components
import qs.config
import qs.services

// Global CPU usage percentage and frequency (on a side bar, a ring filled to
// the usage around the icon, the figures moving to the popup); hover to see
// per-core usage in a popup, click to run its action (Settings.cpuAction).
Item {
  id: root

  // Whether it shows as a ring around its icon (its figures in the popup): with
  // the vertical layout (Settings.cpuLayout), and with the automatic one on a
  // side bar.
  readonly property bool ring: Settings.cpuLayout === "vertical" || (Settings.cpuLayout === "auto" && Theme.barVertical)

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: root.ring ? ring.implicitWidth : content.implicitWidth
  implicitHeight: root.ring ? ring.implicitHeight : content.implicitHeight

  BarStack {
    id: content
    visible: !root.ring
    anchors.centerIn: parent
    gap: 10

    BarText {
      text: "󰻠"
    }

    BarText {
      text: Math.round(SystemStats.cpuPercent) + "%"
    }

    BarText {
      text: SystemStats.cpuFrequencyGhz.toFixed(1) + "GHz"
    }
  }

  BarGauge {
    id: ring
    visible: root.ring
    anchors.centerIn: parent
    value: SystemStats.cpuPercent / 100
    icon: "󰻠"
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      popup.dismiss()
      WidgetActions.run("cpu")
    }
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  HoverPopup {
    id: popup
    anchorItem: root
    marginRight: -Theme.pillPadding

    PopupTitle {
      text: I18n.tr("settings.widget.cpu")
    }

    // What the bar shows, when it's a ring.
    ThemedText {
      visible: root.ring
      text: I18n.tr("cpu.summary", Math.round(SystemStats.cpuPercent), SystemStats.cpuFrequencyGhz.toFixed(1))
    }

    Repeater {
      model: SystemStats.corePercents.length

      ThemedText {
        required property int index

        text: I18n.tr("cpu.core", index) + " : " + Math.round(SystemStats.corePercents[index]) + "%"
      }
    }
  }
}
