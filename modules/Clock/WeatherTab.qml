import QtQuick
import qs.components
import qs.config
import qs.services

// The weather page of the clock popup, from services/Weather.qml: the
// conditions now (with the place and when it was fetched), the next hours,
// and the next days, each day's low and high placed on the week's range. In
// Celsius or Fahrenheit (Settings.weatherUnit), for the place set in the
// settings or found from the internet address.
Item {
  id: root

  implicitHeight: Weather.current ? column.implicitHeight : message.implicitHeight

  // The week's lowest and highest temperatures, for the days' bars.
  readonly property real weekMin: Math.min(...Weather.days.map(day => day.min))
  readonly property real weekMax: Math.max(...Weather.days.map(day => day.max))

  // A temperature, rounded, with its degree sign.
  function degrees(value) {
    return Math.round(value) + "°"
  }

  // A rounded panel grouping one topic (as on the performance page).
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
      spacing: 8

      Row {
        visible: card.title !== ""
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

  // No weather yet: fetching it, or why it couldn't be.
  Column {
    id: message
    visible: !Weather.current
    width: parent.width
    topPadding: 30
    bottomPadding: 30
    spacing: 10

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Weather.error ? "󰖪" : "󰖐"
      sizeScale: 2.4
      opacity: 0.5
    }

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(implicitWidth, parent.width)
      wrapMode: Text.Wrap
      horizontalAlignment: Text.AlignHCenter
      text: Weather.error === "place" ? I18n.tr("weather.errorPlace", Settings.weatherLocation)
        : Weather.error === "network" ? I18n.tr("weather.errorNetwork")
        : I18n.tr("weather.loading")
      opacity: 0.6
    }

    RetryButton {
      anchors.horizontalCenter: parent.horizontalCenter
    }
  }

  // Fetches the weather again, after a failure.
  component RetryButton: Rectangle {
    visible: Weather.error !== "" && !Weather.loading
    width: retryText.implicitWidth + 24
    height: retryText.implicitHeight + 10
    radius: Theme.radiusFor(height)
    color: retryMouse.containsMouse ? Theme.borderColor : "transparent"
    border.color: Theme.outlineColor
    border.width: 1

    ThemedText {
      id: retryText
      anchors.centerIn: parent
      text: I18n.tr("weather.retry")
      sizeScale: 0.8
    }

    MouseArea {
      id: retryMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Weather.refresh()
    }
  }

  Column {
    id: column
    visible: Weather.current !== null
    width: parent.width
    spacing: 8

    // Now.
    Card {
      Item {
        width: parent.width
        height: Math.max(now.implicitHeight, placeColumn.implicitHeight)

        Row {
          id: now
          spacing: 14

          ThemedText {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.current ? Weather.iconOf(Weather.current.code, Weather.current.isDay) : ""
            sizeScale: 3.2
            color: Theme.accentColor
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            ThemedText {
              text: Weather.current ? root.degrees(Weather.current.temperature) : ""
              sizeScale: 2
              font.bold: true
            }

            ThemedText {
              text: Weather.current ? I18n.tr("weather." + Weather.kindOf(Weather.current.code)) : ""
            }

            ThemedText {
              text: Weather.current ? [
                I18n.tr("weather.feels", root.degrees(Weather.current.apparent)),
                I18n.tr("weather.humidity", Math.round(Weather.current.humidity)),
                I18n.tr("weather.wind", Math.round(Weather.current.wind) + (Weather.fahrenheit ? " mph" : " km/h"))
              ].join("  ·  ") : ""
              sizeScale: 0.7
              opacity: 0.7
            }
          }
        }

        // Where, and when it was fetched (with a retry after a failure).
        Column {
          id: placeColumn
          anchors.right: parent.right
          anchors.top: parent.top
          width: Math.min(implicitWidth, parent.width - now.width - 12)
          spacing: 2

          ThemedText {
            anchors.right: parent.right
            width: Math.min(implicitWidth, parent.width)
            elide: Text.ElideRight
            text: Weather.place
            sizeScale: 0.75
            opacity: 0.8
          }

          ThemedText {
            anchors.right: parent.right
            text: Weather.loading ? I18n.tr("weather.loading")
              : Weather.error ? I18n.tr(Weather.error === "place" ? "weather.errorPlace" : "weather.errorNetwork", Settings.weatherLocation)
              : Weather.updated ? I18n.tr("weather.updated", Weather.updated.toLocaleTimeString(I18n.locale, Locale.ShortFormat)) : ""
            sizeScale: 0.65
            opacity: 0.55
          }

          RetryButton {
            anchors.right: parent.right
          }
        }
      }
    }

    // The next hours.
    Card {
      title: I18n.tr("weather.hours")
      icon: "󰥔"

      Row {
        width: parent.width

        Repeater {
          model: Weather.hours

          Column {
            required property var modelData
            required property int index

            width: parent.width / Math.max(Weather.hours.length, 1)
            spacing: 4

            ThemedText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: parent.index === 0 ? I18n.tr("weather.now") : parent.modelData.time.toLocaleTimeString(I18n.locale, I18n.tr("weather.hourFormat"))
              sizeScale: 0.65
              opacity: 0.7
            }

            ThemedText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Weather.iconOf(parent.modelData.code, parent.modelData.isDay)
              sizeScale: 1.2
            }

            ThemedText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.degrees(parent.modelData.temperature)
              sizeScale: 0.75
            }
          }
        }
      }
    }

    // The next days.
    Card {
      title: I18n.tr("weather.days")
      icon: "󰃭"

      Repeater {
        model: Weather.days

        Item {
          id: day

          required property var modelData
          required property int index

          width: parent.width
          height: dayName.implicitHeight + 6

          ThemedText {
            id: dayName
            anchors.verticalCenter: parent.verticalCenter
            width: 110
            elide: Text.ElideRight
            text: {
              if (day.index === 0) return I18n.tr("weather.today")
              const name = day.modelData.date.toLocaleDateString(I18n.locale, "dddd")
              return name.charAt(0).toUpperCase() + name.slice(1)
            }
            sizeScale: 0.8
          }

          ThemedText {
            id: dayIcon
            anchors.left: dayName.right
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            horizontalAlignment: Text.AlignHCenter
            text: Weather.iconOf(day.modelData.code, true)
          }

          // The chance of rain, when there's some.
          ThemedText {
            id: rain
            anchors.left: dayIcon.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 56
            text: day.modelData.rain > 0 ? "󰖌 " + day.modelData.rain + "%" : ""
            color: Theme.accentColor
            sizeScale: 0.7
          }

          ThemedText {
            id: low
            anchors.left: rain.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: root.degrees(day.modelData.min)
            sizeScale: 0.8
            opacity: 0.6
          }

          // The day's low to high, on the week's range.
          Rectangle {
            id: range
            anchors.left: low.right
            anchors.leftMargin: 10
            anchors.right: high.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.12)

            Rectangle {
              readonly property real span: Math.max(root.weekMax - root.weekMin, 1)
              x: range.width * (day.modelData.min - root.weekMin) / span
              width: Math.max(height, range.width * (day.modelData.max - day.modelData.min) / span)
              height: parent.height
              radius: parent.radius
              color: Theme.accentColor
            }
          }

          ThemedText {
            id: high
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            text: root.degrees(day.modelData.max)
            sizeScale: 0.8
          }
        }
      }
    }
  }
}
