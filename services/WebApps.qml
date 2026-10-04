pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The web apps (Settings.webApps): sites opened with Settings.webAppCommand
// (by default in a window of Zen's "webapp" profile), from the bar's web apps
// widget or over IPC:
//   quickshell -p . ipc call webApps open <name>
// Each one's icon is its site's favicon, found by scripts/favicon.py and kept
// in Paths.faviconDir. A web app whose window is still open is switched to
// instead of opened again: the first window opening in the seconds after a
// web app is launched is taken as its own.
Singleton {
  id: root

  // The web apps the widget's menu offers: those switched on, in order.
  readonly property var shown: Settings.webApps.filter(app => app.on)

  // The icons found, by web app address: a file path, or "" for a site
  // whose icon wasn't found (looked for again only when the shell restarts).
  property var icons: ({})
  // The addresses the running search is for.
  property var searching: []

  // The icon of web app `app` as an image source, "" while there is none.
  function iconOf(app) {
    const path = root.icons[app.url] ?? ""
    return path !== "" ? "file://" + path : ""
  }

  // How long after a launch a window opening is taken as the web app's, in
  // milliseconds (a browser starting cold takes a few seconds).
  readonly property int claimTime: 15000
  // The web apps launched and waiting for their window, oldest first:
  // [{ url, until }], `until` the time the wait ends.
  property var waiting: []

  // The open window of each web app, by address: Hyprland's window address
  // (without "0x").
  property var windows: ({})

  // The window of web app `app` if it is still open, else null.
  function windowOf(app) {
    const address = root.windows[app.url]
    if (!address) return null
    return Hyprland.toplevels.values.find(toplevel => toplevel.address.replace(/^0x/, "") === address) ?? null
  }

  // Whether web app `app`'s window is open.
  function isOpen(app) {
    return root.windowOf(app) !== null
  }

  // Switches to web app `app`'s window when it is open, else opens it: the
  // command's words, with %s in them replaced by the address (or the
  // address added at the end without one), run as they are, without a
  // shell.
  function launch(app) {
    const window = root.windowOf(app)
    if (window) {
      Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:0x" + window.address.replace(/^0x/, "")) + " })")
      return
    }
    const words = root.split(Settings.webAppCommand)
    if (words.length === 0) return
    root.waiting = root.waiting.filter(other => other.url !== app.url).concat([{ url: app.url, until: Date.now() + root.claimTime }])
    const command = words.some(word => word.includes("%s")) ? words.map(word => word.split("%s").join(app.url)) : words.concat([app.url])
    Quickshell.execDetached(command)
  }

  // `text` split into words as a shell would, without running anything:
  // on spaces, except inside single or double quotes, a backslash keeping
  // the character after it.
  function split(text) {
    const words = []
    let word = null
    let quote = ""
    for (let i = 0; i < text.length; i++) {
      const c = text[i]
      if (quote !== "") {
        if (c === quote) quote = ""
        else if (c === "\\" && quote === "\"" && i + 1 < text.length) word += text[++i]
        else word += c
      } else if (c === "'" || c === "\"") {
        quote = c
        word = word ?? ""
      } else if (c === "\\" && i + 1 < text.length) {
        word = (word ?? "") + text[++i]
      } else if (/\s/.test(c)) {
        if (word !== null) words.push(word)
        word = null
      } else {
        word = (word ?? "") + c
      }
    }
    if (word !== null) words.push(word)
    return words
  }

  // Looks for the icons of the web apps that have none yet (one search at a
  // time: a change during one is looked at once it ends).
  function findIcons() {
    if (finder.running) return
    const missing = Settings.webApps.map(app => app.url).filter(url => root.icons[url] === undefined)
    if (missing.length === 0) return
    root.searching = missing
    finder.command = ["python3", Paths.faviconScript, Paths.faviconDir].concat(missing)
    finder.running = true
  }

  Component.onCompleted: root.findIcons()

  Connections {
    target: Settings
    function onWebAppsChanged() {
      root.findIcons()
    }
  }

  Process {
    id: finder
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.icons = Object.assign({}, root.icons, JSON.parse(this.text))
        } catch (error) {}
      }
    }
    // An address the search gave nothing for (it failed) counts as without
    // an icon, so it isn't searched for again and again.
    onExited: {
      const icons = Object.assign({}, root.icons)
      for (const url of root.searching) icons[url] = icons[url] ?? ""
      root.icons = icons
      Qt.callLater(root.findIcons)
    }
  }

  Connections {
    target: Hyprland

    // openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE: the window of the web app
    // waiting longest, if any; closewindow>>ADDRESS: that web app's window
    // is gone.
    function onRawEvent(event) {
      if (event.name === "openwindow") {
        const now = Date.now()
        const waiting = root.waiting.filter(other => other.until > now)
        if (waiting.length === 0) {
          root.waiting = []
          return
        }
        root.waiting = waiting.slice(1)
        root.windows = Object.assign({}, root.windows, { [waiting[0].url]: event.data.split(",")[0] })
      } else if (event.name === "closewindow") {
        const windows = {}
        for (const url in root.windows) {
          if (root.windows[url] !== event.data) windows[url] = root.windows[url]
        }
        root.windows = windows
      }
    }
  }

  IpcHandler {
    target: "webApps"

    // The web apps as JSON, in order: [{ "name", "url", "on", "open" }],
    // `open` whether its window is open.
    function list(): string {
      return JSON.stringify(Settings.webApps.map(app => Object.assign({ open: root.isOpen(app) }, app)))
    }

    // Opens the web app named `name` (any case), on or not, or switches to
    // its window when it is open.
    function open(name: string): void {
      const app = Settings.webApps.find(app => app.name.toLowerCase() === name.trim().toLowerCase())
      if (app) root.launch(app)
    }
  }
}
