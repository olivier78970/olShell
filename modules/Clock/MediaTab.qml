import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.config

// The media page of the clock popup: a player for any app speaking MPRIS
// (music players, browsers, video players...). The track's cover, title,
// artist and album, its progress (click or drag to seek, where the app
// allows it), the controls (shuffle, previous, play/pause, next, repeat, each
// shown when the app supports it), the app's volume, and a button bringing
// the app forward. With several apps playing, a chip per app picks the one
// shown, the one playing by default.
Item {
  id: root

  // The players: every app's but playerctld's, which only stands in for the
  // others (it would show each of them twice).
  readonly property var players: Mpris.players.values.filter(player => !player.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld"))
  // The one picked with the chips, while it's still there.
  property var picked: null
  // The one shown: the one picked, or else one playing, or else the first.
  readonly property var player: root.players.includes(root.picked) ? root.picked
    : root.players.find(player => player.isPlaying) ?? root.players[0] ?? null

  implicitHeight: root.player ? column.implicitHeight : empty.implicitHeight

  // Whether the app gives the track's length right now (a browser often
  // doesn't, or only for a moment: Firefox and Zen give it at the start of
  // some YouTube videos, then drop it).
  readonly property bool reportsLength: (root.player?.lengthSupported ?? false) && root.player.length > 0
  // The track, told apart from the next by its app, address and title.
  readonly property string trackKey: root.player
    ? root.player.dbusName + "|" + (root.player.metadata["xesam:url"] ?? "") + "|" + root.player.trackTitle : ""
  // The last length and position the app gave for the track, and when: the
  // bar carries on from them, counting the time itself while the track plays,
  // when the app stops giving them part way through.
  property string knownKey: ""
  property real knownLength: 0
  property real knownPosition: 0
  property real knownTime: 0
  // The time now, in milliseconds, moved on every second the bar moves.
  property real now: Date.now()

  // Whether there's a length to show (given, or remembered for this track),
  // and the length and position shown.
  readonly property bool hasLength: root.reportsLength || (root.knownKey === root.trackKey && root.knownLength > 0)
  readonly property real length: root.reportsLength ? root.player.length : root.knownLength
  readonly property real position: root.reportsLength ? root.player.position
    : Math.min(root.knownLength, root.knownPosition + (root.player?.isPlaying ? (root.now - root.knownTime) / 1000 : 0))

  // Keeps what the app gives, while it gives it.
  function remember() {
    if (!root.reportsLength) return
    root.knownKey = root.trackKey
    root.knownLength = root.player.length
    root.knownPosition = root.player.position
    root.knownTime = Date.now()
  }

  // Also while the page is hidden (the popup keeps it), so the length given
  // at the start of a track is kept for when it's shown. While counting the
  // time itself, pausing stops the count where it is, and playing again
  // starts it from there.
  Connections {
    target: root.player

    function onLengthChanged() {
      root.remember()
    }

    function onPositionChanged() {
      root.remember()
    }

    function onIsPlayingChanged() {
      if (root.reportsLength) {
        root.remember()
      } else if (root.knownKey === root.trackKey) {
        const time = Date.now()
        if (!root.player.isPlaying) root.knownPosition = Math.min(root.knownLength, root.knownPosition + (time - root.knownTime) / 1000)
        root.knownTime = time
        root.now = time
      }
    }
  }

  onVisibleChanged: root.now = Date.now()

  // "m:ss" (or "h:mm:ss") for a time in seconds.
  function formatTime(seconds) {
    const total = Math.max(0, Math.floor(seconds))
    const h = Math.floor(total / 3600)
    const m = Math.floor(total / 60) % 60
    const s = String(total % 60).padStart(2, "0")
    return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + s : m + ":" + s
  }

  // MPRIS doesn't announce the position as it moves: asked again every
  // second while a track plays and the page shows.
  Timer {
    interval: 1000
    repeat: true
    running: root.visible && root.player !== null && root.player.isPlaying && root.hasLength
    onTriggered: {
      if (root.reportsLength && root.player.positionSupported) root.player.positionChanged()
      root.now = Date.now()
    }
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
    visible: root.player === null
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

  Column {
    id: column
    visible: root.player !== null
    width: parent.width
    spacing: 12

    // A chip per app, when there's more than one to choose from.
    Flow {
      visible: root.players.length > 1
      width: parent.width
      spacing: 6

      Repeater {
        model: root.players

        Rectangle {
          id: chip

          required property var modelData
          readonly property bool current: chip.modelData === root.player

          width: chipRow.implicitWidth + 20
          height: chipRow.implicitHeight + 10
          radius: Theme.radiusFor(height)
          color: chip.current ? Theme.accentColor : chipMouse.containsMouse ? Theme.borderColor : "transparent"
          border.color: chip.current ? Theme.accentColor : Theme.outlineColor
          border.width: 1

          Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            ThemedText {
              anchors.verticalCenter: parent.verticalCenter
              text: chip.modelData.isPlaying ? "󰐊" : "󰏤"
              sizeScale: 0.7
              color: chip.current ? Theme.backgroundColor : Theme.textColor
            }

            ThemedText {
              anchors.verticalCenter: parent.verticalCenter
              text: chip.modelData.identity
              sizeScale: 0.8
              color: chip.current ? Theme.backgroundColor : Theme.textColor
            }
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked = chip.modelData
          }
        }
      }
    }

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
          source: root.player?.trackArtUrl ?? ""
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
          text: root.player?.trackTitle || I18n.tr("media.unknownTitle")
          font.bold: true
        }

        ThemedText {
          visible: text.length > 0
          width: parent.width
          elide: Text.ElideRight
          text: root.player?.trackArtist ?? ""
          sizeScale: 0.85
        }

        ThemedText {
          visible: text.length > 0
          width: parent.width
          elide: Text.ElideRight
          text: root.player?.trackAlbum ?? ""
          sizeScale: 0.75
          opacity: 0.6
        }

        // The app, which the button brings forward where it allows it.
        Row {
          spacing: 2

          ThemedText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.player?.identity ?? ""
            sizeScale: 0.7
            opacity: 0.5
          }

          IconButton {
            visible: root.player?.canRaise ?? false
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰏌"
            sizeScale: 0.7
            onClicked: {
              root.player.raise()
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
        text: !root.hasLength ? "–:––" : root.formatTime(progress.dragging ? progress.dragValue * root.length : root.position)
        sizeScale: 0.7
        opacity: 0.7
      }

      ValueBar {
        id: progress
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - elapsed.width - total.width - parent.spacing * 2
        value: root.hasLength ? root.position / root.length : 0
        // Seeking needs the app's own length: not while counting the time.
        interactive: root.reportsLength && (root.player?.canSeek ?? false) && (root.player?.positionSupported ?? false)
        onMoved: value => root.player.position = value * root.player.length
      }

      ThemedText {
        id: total
        anchors.verticalCenter: parent.verticalCenter
        text: root.hasLength ? root.formatTime(root.length) : "–:––"
        sizeScale: 0.7
        opacity: 0.7
      }
    }

    // The controls.
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10

      IconButton {
        visible: root.player?.shuffleSupported ?? false
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰒟"
        sizeScale: 1.1
        color: root.player?.shuffle ? Theme.accentColor : Theme.textColor
        opacity: root.player?.shuffle ? 1 : 0.6
        onClicked: root.player.shuffle = !root.player.shuffle
      }

      IconButton {
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.player?.canGoPrevious ?? false
        icon: "󰒮"
        sizeScale: 1.4
        onClicked: root.player.previous()
      }

      // Play / pause, larger, on an accent disc.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 52
        radius: 26
        color: Theme.accentColor
        opacity: root.player?.canTogglePlaying ? 1 : 0.4

        ThemedText {
          anchors.centerIn: parent
          text: root.player?.isPlaying ? "󰏤" : "󰐊"
          sizeScale: 1.6
          color: Theme.backgroundColor
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.player?.canTogglePlaying ?? false
          cursorShape: Qt.PointingHandCursor
          onClicked: root.player.togglePlaying()
        }
      }

      IconButton {
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.player?.canGoNext ?? false
        icon: "󰒭"
        sizeScale: 1.4
        onClicked: root.player.next()
      }

      // Repeat: off, the playlist, then the track.
      IconButton {
        visible: root.player?.loopSupported ?? false
        anchors.verticalCenter: parent.verticalCenter
        readonly property int loop: root.player?.loopState ?? MprisLoopState.None
        icon: loop === MprisLoopState.Track ? "󰑘" : "󰑖"
        sizeScale: 1.1
        color: loop === MprisLoopState.None ? Theme.textColor : Theme.accentColor
        opacity: loop === MprisLoopState.None ? 0.6 : 1
        onClicked: root.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
          : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
      }
    }

    // The app's own volume, where it has one.
    Row {
      visible: root.player?.volumeSupported ?? false
      width: parent.width
      spacing: 10

      ThemedText {
        id: volumeIcon
        anchors.verticalCenter: parent.verticalCenter
        readonly property real volume: root.player?.volume ?? 0
        text: volume <= 0 ? "󰝟" : volume < 0.5 ? "󰖀" : "󰕾"
        opacity: 0.7
      }

      ValueBar {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - volumeIcon.width - parent.spacing
        value: root.player?.volume ?? 0
        interactive: root.player?.canControl ?? false
        onMoved: value => root.player.volume = value
      }
    }
  }
}
