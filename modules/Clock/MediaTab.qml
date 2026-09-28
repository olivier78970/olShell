import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config

// The media page of the clock popup: a card for each app speaking MPRIS
// (music players, browsers, video players...), one under another, in the
// order they appeared (scrolling past a few). Each has the track's cover,
// title, artist and album, its progress (click or drag to seek, where the
// app allows it), the controls (shuffle, previous, play/pause, next, repeat,
// each shown when the app supports it), the app's volume, and a button
// bringing the app forward. A browser is one app, whatever its tabs play.
Item {
  id: root

  // The players: every app's but playerctld's, which only stands in for the
  // others (it would show each of them twice).
  readonly property var players: Mpris.players.values.filter(player => !player.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld"))
  // The tallest the cards get before scrolling.
  readonly property real maxHeight: 620

  implicitHeight: root.players.length > 0 ? Math.min(cards.implicitHeight, root.maxHeight) : empty.implicitHeight

  // "m:ss" (or "h:mm:ss") for a time in seconds.
  function formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds))
    const h = Math.floor(total / 3600)
    const m = Math.floor(total / 60) % 60
    const s = String(total % 60).padStart(2, "0")
    return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s
  }

  // A bar filled up to `value` (0-1) that can be clicked or dragged when
  // `interactive`, reporting the value asked for through `moved`.
  component ValueBar: Item {
    id: bar

    property real value: 0
    property bool interactive: true
    // While dragging, the value under the pointer (the real one may lag).
    property real dragValue: 0
    readonly property bool dragging: barMouse.pressed
    readonly property real shown: bar.dragging ? bar.dragValue : Math.max(0, Math.min(1, bar.value))
    signal moved(real value)

    implicitHeight: 16

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: height / 2
      color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.15)

      Rectangle {
        width: track.width * bar.shown
        height: parent.height
        radius: parent.radius
        color: Theme.accentColor
      }
    }

    Rectangle {
      visible: bar.interactive && (barMouse.containsMouse || bar.dragging)
      x: track.width * bar.shown - width / 2
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      height: 14
      radius: 7
      color: Theme.accentColor
    }

    MouseArea {
      id: barMouse
      anchors.fill: parent
      enabled: bar.interactive
      hoverEnabled: true
      cursorShape: bar.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

      function valueAt(x) {
        return Math.max(0, Math.min(1, x / width))
      }

      onPressed: mouse => bar.dragValue = valueAt(mouse.x)
      onPositionChanged: mouse => {
        if (pressed) bar.dragValue = valueAt(mouse.x)
      }
      onReleased: mouse => bar.moved(valueAt(mouse.x))
    }
  }

  // Nothing playing.
  Column {
    id: empty
    visible: root.players.length === 0
    width: parent.width
    topPadding: 30
    bottomPadding: 30
    spacing: 8

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "󰝛"
      sizeScale: 2.4
      opacity: 0.5
    }

    ThemedText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: I18n.tr("media.none")
      opacity: 0.6
    }
  }

  Flickable {
    visible: root.players.length > 0
    anchors.fill: parent
    contentHeight: cards.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: cards
      width: parent.width
      spacing: 8

      Repeater {
        model: root.players

        // One app's player.
        Rectangle {
          id: card

          required property var modelData
          readonly property var player: card.modelData

          // What the app gives, and what's shown, of the track's length and
          // position. Whether it gives the length right now (a browser often
          // doesn't, or only for a moment: Firefox and Zen give it at the
          // start of some YouTube videos, then drop it).
          readonly property bool reportsLength: card.player.lengthSupported && card.player.length > 0
          // The track, told apart from the next by its address and title.
          readonly property string trackKey: (card.player.metadata["xesam:url"] ?? "") + "|" + card.player.trackTitle
          // The last length and position the app gave for the track, and
          // when: the bar carries on from them, counting the time itself
          // while the track plays, when the app stops giving them part way
          // through.
          property string knownKey: ""
          property real knownLength: 0
          property real knownPosition: 0
          property real knownTime: 0
          // The time now, in milliseconds, moved on every second the bar moves.
          property real now: Date.now()
          // Whether there's a length to show (given, or remembered for this
          // track), and the length and position shown.
          readonly property bool hasLength: card.reportsLength || (card.knownKey === card.trackKey && card.knownLength > 0)
          readonly property real length: card.reportsLength ? card.player.length : card.knownLength
          readonly property real position: card.reportsLength ? card.player.position
            : Math.min(card.knownLength, card.knownPosition + (card.player.isPlaying ? (card.now - card.knownTime) / 1000 : 0))

          // Keeps what the app gives, while it gives it.
          function remember() {
            if (!card.reportsLength) return
            card.knownKey = card.trackKey
            card.knownLength = card.player.length
            card.knownPosition = card.player.position
            card.knownTime = Date.now()
          }

          width: parent.width
          height: content.implicitHeight + 24
          radius: Theme.radiusFor(Math.min(height, 120))
          color: Qt.rgba(Theme.backgroundColor.r, Theme.backgroundColor.g, Theme.backgroundColor.b, 0.45)
          border.color: Qt.rgba(Theme.outlineColor.r, Theme.outlineColor.g, Theme.outlineColor.b, 0.5)
          border.width: Theme.borderWidth > 0 ? 1 : 0

          Component.onCompleted: card.remember()

          // Also while the page is hidden (the popup keeps it), so the length
          // given at the start of a track is kept for when it's shown. While
          // counting the time itself, pausing stops the count where it is,
          // and playing again starts it from there.
          Connections {
            target: card.player

            function onLengthChanged() {
              card.remember()
            }

            function onPositionChanged() {
              card.remember()
            }

            function onIsPlayingChanged() {
              if (card.reportsLength) {
                card.remember()
              } else if (card.knownKey === card.trackKey) {
                const time = Date.now()
                if (!card.player.isPlaying) card.knownPosition = Math.min(card.knownLength, card.knownPosition + (time - card.knownTime) / 1000)
                card.knownTime = time
                card.now = time
              }
            }
          }

          // MPRIS doesn't announce the position as it moves: asked again
          // every second while a track plays and the page shows.
          Timer {
            interval: 1000
            repeat: true
            running: root.visible && card.player.isPlaying && card.hasLength
            onTriggered: {
              if (card.reportsLength && card.player.positionSupported) card.player.positionChanged()
              card.now = Date.now()
            }
          }

          Connections {
            target: root

            function onVisibleChanged() {
              card.now = Date.now()
            }
          }

          Column {
            id: content
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 12

            // The cover, and the track beside it.
            Row {
              width: parent.width
              spacing: 14

              ClippingRectangle {
                id: cover
                width: 120
                height: 120
                radius: Theme.radiusFor(height)
                color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.08)

                Image {
                  id: art
                  anchors.fill: parent
                  source: card.player?.trackArtUrl ?? ""
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  sourceSize.width: 240
                  sourceSize.height: 240
                }

                // No cover: a note instead.
                ThemedText {
                  visible: art.status !== Image.Ready
                  anchors.centerIn: parent
                  text: "󰝚"
                  sizeScale: 2.4
                  opacity: 0.5
                }
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - cover.width - parent.spacing
                spacing: 4

                ThemedText {
                  width: parent.width
                  wrapMode: Text.Wrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                  text: card.player?.trackTitle || I18n.tr("media.unknownTitle")
                  font.bold: true
                }

                ThemedText {
                  visible: text.length > 0
                  width: parent.width
                  elide: Text.ElideRight
                  text: card.player?.trackArtist ?? ""
                  sizeScale: 0.85
                }

                ThemedText {
                  visible: text.length > 0
                  width: parent.width
                  elide: Text.ElideRight
                  text: card.player?.trackAlbum ?? ""
                  sizeScale: 0.75
                  opacity: 0.6
                }

                // The app, which the button brings forward where it allows it.
                Row {
                  spacing: 2

                  ThemedText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.player?.identity ?? ""
                    sizeScale: 0.7
                    opacity: 0.5
                  }

                  IconButton {
                    visible: card.player?.canRaise ?? false
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "󰏌"
                    sizeScale: 0.7
                    onClicked: {
                      card.player.raise()
                      ClockPanelState.visible = false
                    }
                  }
                }
              }
            }

            // The progress, and the times on either side of it; left empty, with
            // dashes for the times, when the app doesn't give the track's length.
            Row {
              width: parent.width
              spacing: 10

              ThemedText {
                id: elapsed
                anchors.verticalCenter: parent.verticalCenter
                text: !card.hasLength ? "–:––" : root.formatTime(progress.dragging ? progress.dragValue * card.length : card.position)
                sizeScale: 0.7
                opacity: 0.7
              }

              ValueBar {
                id: progress
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - elapsed.width - total.width - parent.spacing * 2
                value: card.hasLength ? card.position / card.length : 0
                // Seeking needs the app's own length: not while counting the time.
                interactive: card.reportsLength && (card.player?.canSeek ?? false) && (card.player?.positionSupported ?? false)
                onMoved: value => card.player.position = value * card.player.length
              }

              ThemedText {
                id: total
                anchors.verticalCenter: parent.verticalCenter
                text: card.hasLength ? root.formatTime(card.length) : "–:––"
                sizeScale: 0.7
                opacity: 0.7
              }
            }

            // The controls.
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 10

              IconButton {
                visible: card.player?.shuffleSupported ?? false
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰒟"
                sizeScale: 1.1
                color: card.player?.shuffle ? Theme.accentColor : Theme.textColor
                opacity: card.player?.shuffle ? 1 : 0.6
                onClicked: card.player.shuffle = !card.player.shuffle
              }

              IconButton {
                anchors.verticalCenter: parent.verticalCenter
                enabled: card.player?.canGoPrevious ?? false
                icon: "󰒮"
                sizeScale: 1.4
                onClicked: card.player.previous()
              }

              // Play / pause, larger, on an accent disc.
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                radius: 26
                color: Theme.accentColor
                opacity: card.player?.canTogglePlaying ? 1 : 0.4

                ThemedText {
                  anchors.centerIn: parent
                  text: card.player?.isPlaying ? "󰏤" : "󰐊"
                  sizeScale: 1.6
                  color: Theme.backgroundColor
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: card.player?.canTogglePlaying ?? false
                  cursorShape: Qt.PointingHandCursor
                  onClicked: card.player.togglePlaying()
                }
              }

              IconButton {
                anchors.verticalCenter: parent.verticalCenter
                enabled: card.player?.canGoNext ?? false
                icon: "󰒭"
                sizeScale: 1.4
                onClicked: card.player.next()
              }

              // Repeat: off, the playlist, then the track.
              IconButton {
                visible: card.player?.loopSupported ?? false
                anchors.verticalCenter: parent.verticalCenter
                readonly property int loop: card.player?.loopState ?? MprisLoopState.None
                icon: loop === MprisLoopState.Track ? "󰑘" : "󰑖"
                sizeScale: 1.1
                color: loop === MprisLoopState.None ? Theme.textColor : Theme.accentColor
                opacity: loop === MprisLoopState.None ? 0.6 : 1
                onClicked: card.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                  : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
              }
            }

            // The app's own volume, where it has one.
            Row {
              visible: card.player?.volumeSupported ?? false
              width: parent.width
              spacing: 10

              ThemedText {
                id: volumeIcon
                anchors.verticalCenter: parent.verticalCenter
                readonly property real volume: card.player?.volume ?? 0
                text: volume <= 0 ? "󰝟" : volume < 0.5 ? "󰖀" : "󰕾"
                opacity: 0.7
              }

              ValueBar {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - volumeIcon.width - parent.spacing
                value: card.player?.volume ?? 0
                interactive: card.player?.canControl ?? false
                onMoved: value => card.player.volume = value
              }
            }
          }
        }
      }
    }
  }
}
