pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Downloads Bing's picture of the day (scripts/bing-picture.py) into
// Settings.bingWallpaperFolder when Settings.bingWallpapers is on: once at startup, and
// each time the setting is turned on. It applies nothing: the wallpaper panel
// lists the pictures with the others. A wallpaper saved as "pod" (`podTag`)
// stands for the newest picture of the folder (`latest`).
Singleton {
  id: root

  readonly property bool enabled: Settings.bingWallpapers
  // Settings load a moment after this singleton's first frame (see Blur.qml's
  // `settled`): `enabled` first reads its default, off, so the startup
  // download waits for the saved value.
  property bool settled: false

  // What a wallpaper saved in ThemeState is called when it is the picture of
  // the day instead of a file.
  readonly property string podTag: "pod"
  // The newest picture of the Bing folder: the one whose file name holds the
  // latest date (bing-<date>.jpg, or <date>.jpg for older ones, the date as
  // YYYYMMDD); empty until the folder has been read, or when no file has a date.
  property string latest: ""

  // The file a saved wallpaper stands for: the newest picture for "pod", else the path itself.
  function resolve(path) {
    return path === root.podTag ? root.latest : path
  }

  onEnabledChanged: if (root.settled && root.enabled) root.fetch()

  Timer {
    interval: 500
    running: true
    onTriggered: {
      root.settled = true
      root.scan()
      if (root.enabled) root.fetch()
    }
  }

  // Starts the download, unless one is still running.
  function fetch() {
    const folder = Settings.bingWallpaperFolder
    if (fetchProcess.running) return
    fetchProcess.command = ["python3", Paths.bingPictureScript, folder, "--days", "8", "--notify", I18n.tr("bingWallpapers.notification"), I18n.tr("bingWallpapers.link")]
    fetchProcess.running = true
  }

  // Reads the folder again, to find the newest picture.
  function scan() {
    scanProcess.running = true
  }

  // Another folder, another newest picture.
  Connections {
    target: Settings
    function onBingWallpaperFolderChanged() {
      if (root.settled) root.scan()
    }
  }

  Process {
    id: fetchProcess
    // Whether the download worked or not (offline), the folder may hold a
    // newer picture than `latest`.
    onRunningChanged: if (!running) root.scan()
    // Only a failure writes to stderr.
    stderr: StdioCollector {
      onStreamFinished: if (text.trim().length > 0) console.warn("BingWallpaper: " + text.trim())
    }
  }

  Process {
    id: scanProcess
    command: ["find", Settings.bingWallpaperFolder, "-maxdepth", "1", "-type", "f", "-iregex", ".*\\.\\(jpg\\|jpeg\\|png\\|webp\\)"]
    stdout: StdioCollector {
      onStreamFinished: {
        const prefix = Settings.bingWallpaperFolder + "/"
        let found = ""
        let date = ""
        text.split("\n").forEach(path => {
          const day = path.startsWith(prefix) ? path.slice(prefix.length).match(/^(?:bing-)?(\d{8})\.[^.]+$/)?.[1] ?? "" : ""
          if (day > date) {
            date = day
            found = path
          }
        })
        root.latest = found
      }
    }
  }
}
