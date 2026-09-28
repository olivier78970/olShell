import QtQuick
import qs.components
import qs.config
import qs.services

// Instant download and upload speed of the physical network interfaces.
// Each figure has a fixed width (that of the longest text it can show), so
// the bar doesn't shift around as the numbers change. On a side bar (or with
// Settings.networkRing) each arrow has a ring around it instead, filled to its
// rate, and the figures show in a popup on hover. Click to open or close btop
// with only its network box.
Item {
  id: root

  // Whether it shows as rings (its figures in the popup): always on a side
  // bar, and on a top or bottom bar too with its setting.
  readonly property bool ring: Theme.barVertical || Settings.networkRing
  // The rate that fills a ring: the highest of the last minute's (`history`,
  // one reading a second), but at least 1 MiB/s, so a trickle doesn't fill it.
  function scale(history) {
    return Math.max(1024 * 1024, ...history)
  }

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: root.ring ? rings.implicitWidth : content.implicitWidth
  implicitHeight: root.ring ? rings.implicitHeight : content.implicitHeight

  TextMetrics {
    id: widest
    font.family: Theme.fontFamily
    font.weight: Theme.fontWeight
    font.letterSpacing: Theme.fontLetterSpacing
    font.italic: Theme.fontItalic
    font.pixelSize: Theme.fontSize()
    text: "1023 " + I18n.value("format.units")[1] + "/s"
  }

  Row {
    id: content
    visible: !root.ring
    anchors.centerIn: parent
    spacing: 12

    Row {
      spacing: 4

      BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰇚"
        //color: Theme.accentColor
      }

      BarText {
        width: widest.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: SystemStats.formatRate(SystemStats.netDownBps, true)
      }
    }

    Row {
      spacing: 4

      BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰕒"
        //color: Qt.tint(Theme.accentColor, Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.5))
      }

      BarText {
        width: widest.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: SystemStats.formatRate(SystemStats.netUpBps, true)
      }
    }
  }

  // As rings: one per direction, filled to its rate against the highest of
  // the last minute's (see scale).
  BarStack {
    id: rings
    visible: root.ring
    anchors.centerIn: parent
    gap: 6
    stackGap: 6

    BarGauge {
      value: SystemStats.netDownBps / root.scale(SystemStats.downHistory)
      icon: "󰇚"
    }

    BarGauge {
      value: SystemStats.netUpBps / root.scale(SystemStats.upHistory)
      icon: "󰕒"
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Btop.toggle("net")
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
  }

  // The rates, when only the rings show them.
  HoverPopup {
    id: popup
    anchorItem: root
    alignCenter: true
    showWhen: root.ring

    PopupTitle {
      text: I18n.tr("settings.widget.network")
    }

    ThemedText {
      text: "󰇚 " + SystemStats.formatRate(SystemStats.netDownBps)
    }

    ThemedText {
      text: "󰕒 " + SystemStats.formatRate(SystemStats.netUpBps)
    }
  }
}
