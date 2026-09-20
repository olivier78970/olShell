import QtQuick
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// Screen-centered wallpaper picker, toggled from outside via:
//   quickshell -p . ipc call wallpapers wallpapersToggle
// Wallpapers are browsed in a carousel (centered item large, neighbors
// smaller); Enter or a click applies one with waypaper.
// The Bing "picture of the day" can also be applied directly via:
//   quickshell -p . ipc call wallpapers applyPod
CarouselPanel {
  id: root

  readonly property string wallpaperDir: Paths.wallpaperDir
  readonly property string podPath: Paths.wallpaperOfTheDay
  property var wallpapers: []

  title: I18n.tr("wallpaper.title")
  emptyText: I18n.tr("wallpaper.none")
  model: root.wallpapers
  maxPanelWidth: 2000
  maxPanelHeight: 650

  visible: WallpaperPanelState.visible
  onCloseRequested: WallpaperPanelState.visible = false
  onOpened: listProcess.running = true
  onAccepted: index => root.applyPath(root.wallpapers[index])

  IpcHandler {
    target: "wallpapers"

    function wallpapersToggle(): void {
      WallpaperPanelState.toggle()
    }

    function applyPod(): void {
      root.applyPath(root.podPath)
    }
  }

  function applyPath(path) {
    applyProcess.command = ["waypaper", "--wallpaper", path]
    applyProcess.running = true
    // Regenerates GeneratedColors.json, which Theme.qml picks up via
    // FileView, and the other apps' colors. Matugen defers its own start so
    // it doesn't spawn in the same tick as waypaper above.
    Matugen.applyWallpaper(path)
  }

  Process {
    id: listProcess
    // Includes podPath as a search root alongside wallpaperDir: find
    // silently skips it if it doesn't exist, which is how existence is
    // checked here (no extra process/roundtrip needed).
    command: ["find", root.podPath, root.wallpaperDir, "-maxdepth", "1", "-type", "f", "-iregex", ".*\\.\\(jpg\\|jpeg\\|png\\|webp\\)"]

    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n").filter(line => line.length > 0)
        const podExists = lines.includes(root.podPath)
        const saved = lines.filter(line => line !== root.podPath).sort()
        // The Bing "picture of the day" also lands in the saved
        // directory as its newest file, so drop that duplicate once
        // it's shown as the dedicated pod entry instead.
        if (podExists) saved.pop()
        root.wallpapers = podExists ? [root.podPath].concat(saved) : saved
      }
    }
  }

  Process {
    id: applyProcess
  }

  delegate: Component {
    CarouselCard {
      id: card

      aspectRatio: 9 / 16
      selectedScale: 1.6
      onActivated: root.accept()

      Image {
        anchors.fill: parent
        source: "file://" + card.modelData
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Decode at roughly the displayed size (x2 covers the
        // 1.6x scale of the centered item) instead of full
        // resolution, which for Bing wallpapers is huge.
        sourceSize.width: card.width * 2
      }
    }
  }

  PowerMenuOption {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 20
    label: I18n.tr("wallpaper.pod")
    onClicked: {
      // POD is always the first entry (see listProcess above), so
      // selecting it moves the carousel to it instead of just
      // applying it without visually reflecting the change.
      root.currentIndex = 0
      root.accept()
    }
  }
}
