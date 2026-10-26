pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Makes the settings' default applications (Settings.defaultBrowser,
// defaultMail...) the system's, through scripts/default-apps.py: the
// defaults of each kind's MIME types in ~/.config/mimeapps.list, and the
// first terminal of ~/.config/xdg-terminals.list. It applies them at startup
// and again once they have stopped changing, and lists the applications each
// kind can be, for the settings' dropdowns. The mail client may be a web app
// whose site can compose a mail from a mailto: link (Apps.webMailCompose):
// the script then writes a desktop entry handing those links to the shell:
//   quickshell -p . ipc call defaultApps openMail <web app> <mailto: link>
Singleton {
  id: root

  // The kinds of default applications, in the settings' order, each with its
  // setting.
  readonly property var kinds: [
    { kind: "browser", key: "defaultBrowser" },
    { kind: "mail", key: "defaultMail" },
    { kind: "fileManager", key: "defaultFileManager" },
    { kind: "textEditor", key: "defaultTextEditor" },
    { kind: "terminal", key: "defaultTerminal" },
    { kind: "imageViewer", key: "defaultImageViewer" },
    { kind: "videoPlayer", key: "defaultVideoPlayer" },
    { kind: "musicPlayer", key: "defaultMusicPlayer" },
    { kind: "pdfViewer", key: "defaultPdfViewer" },
    { kind: "archiveManager", key: "defaultArchiveManager" },
    { kind: "torrentClient", key: "defaultTorrentClient" }
  ]

  // The installed applications each kind can be: { kind: [{ id, name }] },
  // empty until listed (see refresh()).
  property var candidates: ({})

  // The address composing a mail from a mailto: link on web app `app`'s
  // site (%s for the link), "" when its site can't.
  function composeOf(app) {
    const match = /^\w+:\/\/([^\/:?#]+)/.exec(app?.url ?? "")
    return match ? Apps.webMailCompose[match[1].toLowerCase().replace(/^www\./, "")] ?? "" : ""
  }

  // The web apps that can be the mail client, in order.
  readonly property var mailWebApps: Settings.webApps.filter(app => root.composeOf(app) !== "")

  // The web app the mail client is ({ name, app }, `app` null when no web
  // app has that name), or null when it's an application.
  readonly property var mailWebApp: WidgetActions.webAppOf(Settings.defaultMail)

  // What the system should have, which changes whenever a default does (and
  // gives shell.qml a property to reference).
  readonly property string wanted: root.kinds.map(kind => Settings.get(kind.key))
    .concat([root.composeOf(root.mailWebApp?.app)]).join("|")

  onWantedChanged: settled.restart()
  Component.onCompleted: settled.restart()

  // Lists the applications of each kind again (the settings panel does when
  // it opens, so an application just installed is offered).
  function refresh() {
    if (lister.running) return
    lister.command = ["python3", Paths.defaultAppsScript, "list"].concat(Object.keys(Apps.terminals))
    lister.running = true
  }

  // Waits for the defaults to stop changing (a dropdown stepped through).
  Timer {
    id: settled
    interval: 800
    onTriggered: {
      applier.running = false
      const command = ["python3", Paths.defaultAppsScript, "apply", "--shell-dir", Paths.shellDir]
      const compose = root.composeOf(root.mailWebApp?.app)
      if (compose !== "") command.push("--mail-compose", compose)
      for (const kind of root.kinds) command.push(kind.kind, Settings.get(kind.key))
      applier.command = command
      applier.running = true
    }
  }

  Process {
    id: applier
  }

  Process {
    id: lister
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.candidates = JSON.parse(this.text)
        } catch (error) {}
      }
    }
  }

  IpcHandler {
    target: "defaultApps"

    // Opens mailto: link `link` in web app `name` (any case), on the mail
    // its site composes from it. The desktop entry standing for a web app as
    // the mail client calls it.
    function openMail(name: string, link: string): void {
      const app = Settings.webApps.find(app => app.name.toLowerCase() === name.trim().toLowerCase())
      const compose = root.composeOf(app)
      if (compose !== "") WebApps.launch(app, compose.split("%s").join(encodeURIComponent(link)))
    }
  }
}
