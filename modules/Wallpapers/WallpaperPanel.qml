import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// Wallpaper picker, attached to the bar or centered on the screen (see
// ModalPanel's `placement`, set by Settings.wallpaperPlacement), toggled from outside via:
//   quickshell -p . ipc call wallpapers wallpapersToggle
// Wallpapers are browsed in a carousel, laid out as Settings.wallpaperCarousel
// says (by default the centered one large and in front, the others stacked
// behind it); Enter or a click applies one with awww.
// The Bing "picture of the day", a random wallpaper, or the last one applied
// can also be applied directly via:
//   quickshell -p . ipc call wallpapers applyPod
//   quickshell -p . ipc call wallpapers applyRandom
//   quickshell -p . ipc call wallpapers applyLast
// A wallpaper is applied to the focused monitor only, and remembered for it.
CarouselPanel {
  id: root

  readonly property string podPath: Paths.wallpaperOfTheDay
  property var wallpapers: []
  // The monitor wallpapers are applied to: the focused one. Its wallpaper is
  // the one in use, for the carousel and the random pick.
  readonly property string monitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Matugen.mainMonitor
  readonly property string current: ThemeState.wallpaperOf(root.monitorName)

  title: I18n.tr("wallpaper.title")
  emptyText: I18n.tr("wallpaper.none")
  model: root.wallpapers
  style: Settings.wallpaperCarousel
  sideVisibleCount: Settings.wallpaperSideCount
  maxPanelWidth: 2000
  maxPanelHeight: 650

  open: WallpaperPanelState.visible
  placement: Settings.wallpaperPlacement
  anchorItem: WallpaperPanelState.anchorItem
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

    function applyLast(): void {
      root.applyLast()
    }

    function applyRandom(): void {
      // The list is only read when the panel opens: read it again first.
      root.randomPending = true
      listProcess.running = true
    }
  }

  // A random wallpaper was asked for by IPC and waits for the list to load.
  property bool randomPending: false

  // The index of a random wallpaper other than the one in use (unless it is the
  // only one), or -1 when the list is empty.
  function randomIndex() {
    const indexes = root.wallpapers.map((path, index) => index)
    const others = indexes.filter(index => root.wallpapers[index] !== root.current)
    const pool = others.length > 0 ? others : indexes
    return pool.length > 0 ? pool[Math.floor(Math.random() * pool.length)] : -1
  }

  // Applies the focused monitor's wallpaper again: the one remembered in
  // ThemeState. The colors are regenerated too: the file may have changed
  // since (a new picture of the day is saved over the same pod.jpg).
  // `onlyIfChanged` regenerates them only if it did, or the theme changed (see
  // services/Matugen.qml).
  function applyLast(onlyIfChanged) {
    if (root.current.length > 0)
      root.applyPath(root.current, onlyIfChanged)
  }

  // Applies the remembered wallpapers: the last one applied to every monitor
  // (also those that have none of their own), then each monitor's own on top.
  function restore() {
    if (ThemeState.wallpaper.length === 0) return
    root.applyPath(ThemeState.wallpaper, true, "")
    for (const name of Object.keys(ThemeState.wallpapers))
      if (ThemeState.wallpapers[name] !== ThemeState.wallpaper) root.show(ThemeState.wallpapers[name], name)
  }

  // awww's daemon draws nothing until a wallpaper is sent to it, so the last
  // one is applied as soon as the shell has started. The first one waits a
  // moment: a Process started while the shell is loading silently does
  // nothing.
  Timer {
    running: true
    interval: 1000
    onTriggered: root.restore()
  }

  // A new picture of the day may have been downloaded at login since, over the
  // same pod.jpg: apply it again, only when it is the wallpaper in use.
  Timer {
    running: true
    interval: 5000
    onTriggered: {
      if (Object.values(ThemeState.wallpapers).concat(ThemeState.wallpaper).includes(root.podPath))
        root.restore()
    }
  }

  // Bing's picture of the day is applied as soon as it has been downloaded, to
  // the main monitor only: the other monitors keep their own wallpaper.
  Connections {
    target: BingWallpaper
    function onDownloaded(path) {
      root.applyPath(path, true, Matugen.mainMonitor)
    }
  }

  // Applies a random wallpaper (see randomIndex), moving the carousel to it
  // when the panel is open.
  function applyRandom() {
    const index = root.randomIndex()
    if (index < 0) return
    root.currentIndex = index
    root.applyPath(root.wallpapers[index])
  }

  // Shows `path` on the monitor `monitor` ("" for all of them), without
  // touching the colors. Calls queue up: awww is run one at a time.
  function show(path, monitor) {
    // The script starts awww's daemon when it isn't running, detached from us.
    const transition = ["--transition-type", Settings.wallpaperTransition, "--transition-duration", String(Settings.wallpaperDuration)]
    const outputs = monitor.length > 0 ? ["--outputs", monitor] : []
    root.applyQueue = root.applyQueue.concat([["python3", Paths.applyWallpaperScript].concat(Apps.wallpaperOptions, transition, outputs, [path])])
    if (!applyProcess.running) root.runNext()
  }

  // The commands waiting for awww (see show()).
  property var applyQueue: []

  function runNext() {
    if (root.applyQueue.length === 0) return
    applyProcess.command = root.applyQueue[0]
    root.applyQueue = root.applyQueue.slice(1)
    applyProcess.running = true
  }

  // Applies `path` to `monitor` ("" for all of them; the focused one when
  // left out) and remembers it.
  function applyPath(path, onlyIfChanged, monitor) {
    const target = monitor === undefined ? root.monitorName : monitor
    root.show(path, target)
    // Regenerates GeneratedColors.json, which Theme.qml picks up via
    // FileView, and the other apps' colors. Matugen defers its own start so
    // it doesn't spawn in the same tick as the wallpaper command above.
    Matugen.applyWallpaper(path, onlyIfChanged === true, target)
  }

  Process {
    id: listProcess
    command: ["find"].concat(Settings.wallpaperListedFolders, ["-maxdepth", "1", "-type", "f", "-iregex", ".*\\.\\(jpg\\|jpeg\\|png\\|webp\\)"])

    stdout: StdioCollector {
      onStreamFinished: {
        root.wallpapers = text.split("\n").filter(line => line.length > 0).sort()
        // Open on the wallpaper in use, once the carousel has taken the new
        // list, which resets its position.
        Qt.callLater(root.showIndex, Math.max(0, root.wallpapers.indexOf(root.current)))
        if (root.randomPending) {
          root.randomPending = false
          root.applyRandom()
        }
      }
    }
  }

  Process {
    id: applyProcess
    onRunningChanged: if (!running) root.runNext()
  }

  delegate: Component {
    CarouselCard {
      id: card

      aspectRatio: 9 / 16
      selectedScale: 1.6
      bordered: false
      onActivated: root.accept()

      Image {
        anchors.fill: parent
        source: "file://" + card.modelData
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Smooth when shrunk, as the side cards are.
        mipmap: true
        // Decode at roughly the displayed size (x2 covers the
        // 1.6x scale of the centered item side by side) instead of full
        // resolution, which for Bing wallpapers is huge.
        sourceSize.width: card.width * 2
      }
    }
  }

  // The latest picture of the day in the Bing folder: the one whose file name
  // holds the latest date (bing-<date>.jpg, or <date>.jpg for older ones, the
  // date as YYYYMMDD), or -1 when none has a date.
  function podIndex() {
    const prefix = Settings.bingWallpaperFolder + "/"
    let found = -1
    let latest = ""
    root.wallpapers.forEach((path, index) => {
      if (!path.startsWith(prefix) || path.indexOf("/", prefix.length) >= 0) return
      const date = path.slice(prefix.length).match(/^(?:bing-)?(\d{8})\.[^.]+$/)?.[1] ?? ""
      if (date > latest) {
        latest = date
        found = index
      }
    })
    return found
  }

  // The description scripts/bing-picture.py saved next to the current picture
  // (bing-<date>.json), or null when it has none: its copyright text and link.
  property var info: null
  readonly property string currentPath: root.currentIndex >= 0 ? (root.wallpapers[root.currentIndex] ?? "") : ""

  FileView {
    path: root.currentPath.replace(/\.[^./]+$/, "") + ".json"
    printErrors: false
    onLoaded: {
      try {
        root.info = JSON.parse(text())
      } catch (error) {
        root.info = null
      }
    }
    onLoadFailed: root.info = null
  }

  // Under the carousel: the current picture's copyright text, and a button
  // opening its link, when it has a description.
  Row {
    visible: root.info !== null && typeof root.info.copyright === "string" && root.info.copyright.length > 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 20
    spacing: 16

    ThemedText {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, root.panel.width * 0.6)
      text: root.info?.copyright ?? ""
      elide: Text.ElideRight
    }

    PowerMenuOption {
      visible: typeof root.info?.copyright_link === "string" && root.info.copyright_link.length > 0
      anchors.verticalCenter: parent.verticalCenter
      label: I18n.tr("bingWallpapers.link")
      onClicked: Quickshell.execDetached(["xdg-open", root.info.copyright_link])
    }
  }

  // Only while Bing's picture of the day is downloaded.
  PowerMenuOption {
    id: podButton

    visible: Settings.bingWallpapers
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 20
    label: I18n.tr("wallpaper.pod")
    onClicked: {
      // Moves the carousel to the picture of the day instead of just
      // applying it without visually reflecting the change.
      const index = root.podIndex()
      if (index < 0) return
      root.currentIndex = index
      root.accept()
    }
  }

  // Left of the picture-of-the-day button, or in its place while it is hidden.
  PowerMenuOption {
    anchors.top: parent.top
    anchors.topMargin: 20
    anchors.right: podButton.visible ? podButton.left : parent.right
    anchors.rightMargin: podButton.visible ? 8 : 20
    icon: "\uDB81\uDC9F"
    label: I18n.tr("wallpaper.random")
    onClicked: root.applyRandom()
  }
}
