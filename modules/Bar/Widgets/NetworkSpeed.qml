import QtQuick
import qs.components
import qs.config
import qs.services

// Instant download and upload speed of the physical network interfaces.
// Each figure has a fixed width (that of the longest text it can show), so
// the bar doesn't shift around as the numbers change. Click to open or close
// btop.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  TextMetrics {
    id: widest
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize()
    text: "1023 " + I18n.value("format.units")[1] + "/s"
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: 12

    Row {
      spacing: 4

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰇚"
        color: Theme.accentColor
      }

      ThemedText {
        width: widest.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: SystemStats.formatRate(SystemStats.netDownBps, true)
      }
    }

    Row {
      spacing: 4

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰕒"
        color: Qt.tint(Theme.accentColor, Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.5))
      }

      ThemedText {
        width: widest.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: SystemStats.formatRate(SystemStats.netUpBps, true)
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Btop.toggle()
  }
}
