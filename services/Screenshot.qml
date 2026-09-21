pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// Takes screenshots with scripts/screenshot.py. The mode (the whole screen,
// a rectangle or a window) is the last one chosen, remembered in Settings.
// Called by the bar's screenshot widget, and from outside with:
//   quickshell -p . ipc call screenshot capture         # in the remembered mode (for key bindings)
//   quickshell -p . ipc call screenshot take window     # in another one (not remembered)
//   quickshell -p . ipc call screenshot mode region     # remember a mode
//   quickshell -p . ipc call screenshot edit 1          # annotate with satty afterwards (0: don't)
//   quickshell -p . ipc call screenshot dir ~/Shots     # where pictures go (no argument: print it)
Singleton {
  id: root

  readonly property string mode: Settings.screenshotMode
  // Whether a picture is opened in satty (if installed) once taken.
  readonly property bool edit: Settings.screenshotEdit
  // True while a screenshot is being taken (a rectangle or window is being
  // picked, or the picture saved): a second request waits for the first.
  readonly property bool busy: capture.running

  function take(mode) {
    if (root.busy) return
    const command = ["python3", Paths.screenshotScript, mode || root.mode, Settings.screenshotDir, I18n.tr("screenshot.saved")]
    if (root.edit) command.push("--edit")
    capture.command = command
    capture.running = true
  }

  function setMode(mode) {
    Settings.set("screenshotMode", mode)
  }

  function setEdit(on) {
    Settings.set("screenshotEdit", on)
  }

  Process {
    id: capture

    stderr: StdioCollector {
      onStreamFinished: if (text.length > 0) console.warn("Screenshot:", text.trim())
    }
  }

  IpcHandler {
    target: "screenshot"

    // Takes a screenshot in the remembered mode. IPC calls need all their
    // arguments, so this is the one to bind to a key.
    function capture(): void {
      root.take("")
    }

    // Takes a screenshot: `mode` is screen, region or window (or "" for the
    // remembered one; the argument can't be left out).
    function take(mode: string): void {
      if (mode === "" || Settings.choices.screenshotMode.includes(mode)) root.take(mode)
    }

    function mode(mode: string): void {
      if (Settings.choices.screenshotMode.includes(mode)) root.setMode(mode)
    }

    // Sets the folder pictures are saved in when `path` is not empty (~ is the
    // home folder; a path that isn't absolute is refused), and returns it.
    function dir(path: string): string {
      if (path !== "") Settings.set("screenshotDir", path)
      return Settings.screenshotDir
    }

    // Turns the annotation step on (1) or off (0).
    function edit(on: int): void {
      root.setEdit(on !== 0)
    }
  }
}
