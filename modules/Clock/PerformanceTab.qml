import QtQuick
import qs.components
import qs.config
import qs.services

// The performance page of the clock popup: CPU and memory as gauges with
// their recent history, the network speed in both directions, and each
// disk's usage against its capacity. Figures come from SystemStats.
Item {
  id: root

  implicitHeight: column.implicitHeight

  // A rounded panel grouping one topic.
  component Card: Rectangle {
    id: card

    default property alias content: inner.data
    property string title: ""
    property string icon: ""

    width: parent.width
    height: inner.implicitHeight + 20
    radius: Theme.radiusFor(height)
    color: Qt.rgba(Theme.backgroundColor.r, Theme.backgroundColor.g, Theme.backgroundColor.b, 0.45)
    border.color: Qt.rgba(Theme.outlineColor.r, Theme.outlineColor.g, Theme.outlineColor.b, 0.5)
    border.width: Theme.borderWidth > 0 ? 1 : 0

    Column {
      id: inner
      x: 10
      y: 10
      width: parent.width - 20
      spacing: 6

      Row {
        spacing: 6

        ThemedText {
          text: card.icon
          color: Theme.accentColor
          sizeScale: 0.8
        }

        ThemedText {
          text: card.title
          opacity: 0.7
          sizeScale: 0.75
        }
      }
    }
  }

  Column {
    id: column
    width: parent.width
    spacing: 8

    // CPU and memory side by side
    Row {
      width: parent.width
      spacing: 8

      Card {
        width: (parent.width - 8) / 2
        title: I18n.tr("perf.cpu")
        icon: "󰻠"

        RingGauge {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 100
          height: 100
          value: SystemStats.cpuPercent / 100
          text: Math.round(SystemStats.cpuPercent) + "%"
        }

        ThemedText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: I18n.formatNumber(SystemStats.cpuFrequencyGhz, 1) + " GHz · " + I18n.tr("perf.cores", SystemStats.corePercents.length)
          opacity: 0.7
          sizeScale: 0.7
        }

        Sparkline {
          width: parent.width
          height: 34
          values: SystemStats.cpuHistory
          maxValue: 100
        }
      }

      Card {
        width: (parent.width - 8) / 2
        title: I18n.tr("perf.memory")
        icon: "󰍛"

        RingGauge {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 100
          height: 100
          value: SystemStats.ramPercent / 100
          text: Math.round(SystemStats.ramPercent) + "%"
        }

        ThemedText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: SystemStats.formatBytes(SystemStats.ramUsedKb * 1024) + " / " + SystemStats.formatBytes(SystemStats.ramTotalKb * 1024)
          opacity: 0.7
          sizeScale: 0.7
        }

        Sparkline {
          width: parent.width
          height: 34
          values: SystemStats.ramHistory
          maxValue: 100
        }
      }
    }

    // Network
    Card {
      title: I18n.tr("perf.network")
      icon: "󰌗"

      Repeater {
        model: [
          { label: I18n.tr("perf.download"), icon: "󰇚", speed: SystemStats.netDownBps, history: SystemStats.downHistory, tint: 0 },
          { label: I18n.tr("perf.upload"), icon: "󰕒", speed: SystemStats.netUpBps, history: SystemStats.upHistory, tint: 0.5 }
        ]

        Item {
          id: row

          required property var modelData

          width: parent.width
          height: 46

          Column {
            id: labels
            anchors.verticalCenter: parent.verticalCenter
            width: 140
            spacing: 0

            Row {
              spacing: 6

              ThemedText {
                text: row.modelData.icon
                color: Qt.tint(Theme.accentColor, Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, row.modelData.tint))
                sizeScale: 0.9
              }

              ThemedText {
                text: SystemStats.formatRate(row.modelData.speed)
                sizeScale: 0.9
              }
            }

            ThemedText {
              text: row.modelData.label
              opacity: 0.6
              sizeScale: 0.65
            }
          }

          Sparkline {
            anchors.left: labels.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            values: row.modelData.history
            minMax: 100 * 1024
            color: Qt.tint(Theme.accentColor, Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, row.modelData.tint))
          }
        }
      }
    }

    // Storage
    Card {
      title: I18n.tr("perf.storage")
      icon: "󰋊"

      Repeater {
        // Only the main disk, the one mounted on "/".
        model: SystemStats.disks.filter(disk => disk.mount === "/")

        Item {
          id: disk

          required property var modelData
          readonly property real fraction: disk.modelData.size > 0 ? disk.modelData.used / disk.modelData.size : 0

          width: parent.width
          height: 36

          ThemedText {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width * 0.4
            elide: Text.ElideRight
            text: disk.modelData.mount
            sizeScale: 0.85
          }

          ThemedText {
            anchors.right: parent.right
            anchors.top: parent.top
            text: SystemStats.formatBytes(disk.modelData.used) + " / " + SystemStats.formatBytes(disk.modelData.size) + "  ·  " + Math.round(disk.fraction * 100) + "%"
            opacity: 0.8
            sizeScale: 0.75
          }

          // Usage bar
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 8
            radius: Theme.radiusFor(height)
            color: Theme.borderColor

            Rectangle {
              width: Math.max(parent.height, parent.width * Math.min(1, disk.fraction))
              height: parent.height
              radius: Theme.radiusFor(height)
              color: disk.fraction > 0.9 ? Theme.warningColor : Theme.accentColor

              Behavior on width {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
              }
            }
          }
        }
      }
    }
  }
}
