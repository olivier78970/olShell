pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Downloads Bing's picture of the day (scripts/bing-picture.py) into
// Settings.bingWallpaperFolder when Settings.bingWallpapers is on: once at startup, and
// each time the setting is turned on. The wallpaper panel lists it with the
// other pictures, and applies it as the wallpaper once it has it (`downloaded`).
Singleton {
  id: root

  readonly property bool enabled: Settings.bingWallpapers
  // Settings load a moment after this singleton's first frame (see Blur.qml's
  // `settled`): `enabled` first reads its default, off, so the startup
  // download waits for the saved value.
  property bool settled: false

  // The picture of the day is in the folder (just downloaded, or already there): its path.
  signal downloaded(string path)

  onEnabledChanged: if (root.settled && root.enabled) root.fetch()

  Timer {
    interval: 500
    running: true
    onTriggered: {
      root.settled = true
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

  Process {
    id: fetchProcess
    // The script prints the picture's path as its last line, and only on success.
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n").filter(line => line.startsWith("/"))
        if (lines.length > 0) root.downloaded(lines[lines.length - 1])
      }
    }
    // Only a failure writes to stderr.
    stderr: StdioCollector {
      onStreamFinished: if (text.trim().length > 0) console.warn("BingWallpaper: " + text.trim())
    }
  }
}
