import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// Launcher, toggled from outside via:
//   quickshell -p . ipc call launcher toggle
// or from the bar's launcher icon. Three tabs search what's typed: the
// installed applications, the files and folders of the home folder (with fd),
// and the web (the default browser's default engine, or an address typed in).
// Tab / Shift+Tab (with or without Ctrl, or Alt+1..4, or a click) switch
// tabs, keeping the text; Up/Down (or Ctrl+N/P) move, Enter opens, Escape
// closes.
ModalPanel {
  id: root

  property string query: ""
  // The tab shown: 0 all, 1 applications, 2 files, 3 web.
  property int tab: 0
  readonly property int allTab: 0
  readonly property int appsTab: 1
  readonly property int filesTab: 2
  readonly property int webTab: 3
  readonly property var tabs: [
    { label: I18n.tr("launcher.tab.all"), icon: "󰍉" },
    { label: I18n.tr("launcher.tab.apps"), icon: "󰀻" },
    { label: I18n.tr("launcher.tab.files"), icon: "󰉋" },
    { label: I18n.tr("launcher.tab.web"), icon: "󰖟" }
  ]
  // What the tab shows: { kind: "app", entry }, { kind: "file", path, name,
  // dir, isDir }, { kind: "web", url, title, subtitle } - and, in the all
  // tab, { kind: "heading", title } over each section (never selected).
  readonly property var results: root.tab === root.appsTab ? root.appResults(root.query)
    : root.tab === root.filesTab ? root.fileResults
    : root.tab === root.webTab ? root.webResults(root.query)
    : root.allResults(root.query)
  // How many of each the all tab shows.
  readonly property int allAppCount: 5
  readonly property int allFileCount: 5
  // The files tab's results, for `fileResultsQuery` (fd runs in the
  // background, see searchFiles()).
  property var fileResults: []
  property string fileResultsQuery: ""
  readonly property bool filesPending: root.tab === root.filesTab && root.query.trim() !== "" && root.fileResultsQuery !== root.query.trim()

  // The application whose tooltip is (about to be) shown, where the pointer
  // was (in panel coordinates), and whether it's visible yet.
  property var tipEntry: null
  property real tipX: 0
  property real tipY: 0
  property bool tipShown: false

  // The height of a result and of a section's heading (the all tab).
  readonly property real resultHeight: 52
  readonly property real headingHeight: 30
  // The list is as tall as the results it shows, up to as many as the
  // settings ask for (Settings.launcherResults), the rest scrolling; and at
  // least one row, for the hint or "no results".
  readonly property real maxListHeight: Settings.launcherResults * (root.resultHeight + list.spacing) - list.spacing
  readonly property real resultsHeight: root.results.reduce((sum, item) => sum + (item.kind === "heading" ? root.headingHeight : root.resultHeight) + list.spacing, -list.spacing)
  readonly property real listHeight: Math.max(root.resultHeight, Math.min(root.maxListHeight, root.resultsHeight))
  // The margins, the tabs and the search box, with the space between them
  // and the list.
  readonly property real chromeHeight: 32 + tabBar.height + searchBox.height + 24

  maxPanelWidth: 640
  maxPanelHeight: root.chromeHeight + root.listHeight
  // The search box stays put while the list grows and shrinks.
  placementHeight: root.chromeHeight + root.maxListHeight
  focusTarget: input

  open: LauncherState.visible
  onCloseRequested: LauncherState.visible = false
  onOpened: {
    // The tab chosen in the settings (their ids are in the tabs' order).
    root.switchTab(Math.max(0, Settings.choices.launcherTab.indexOf(Settings.launcherTab)))
    root.fileResults = []
    root.fileResultsQuery = ""
    input.text = ""
    list.currentIndex = 0
    root.leaveEntry()
    // Pick up applications installed since the last look.
    DesktopLocale.refresh()
    // Pick up a change of the browser's default search engine.
    WebSearch.refresh()
  }

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      LauncherState.toggle()
    }
  }

  // The texts of an application in the shell's language, read from its
  // .desktop file (see DesktopLocale); Quickshell's own, which are in the
  // system's language, when that file can't be found.
  function describe(entry) {
    const local = DesktopLocale.info(entry.id)
    return {
      name: local?.name ?? entry.name,
      genericName: local?.genericName ?? entry.genericName ?? "",
      comment: local?.comment ?? entry.comment ?? "",
      keywords: local ? local.keywords : (entry.keywords ?? []),
      // The untranslated name: still worth matching ("files" in a French UI).
      defaultName: local?.defaultName ?? ""
    }
  }

  // How well an application, whose texts are `text` (see describe()), matches
  // the (lowercase) query, 0 for no match: name first (exact, prefix, word
  // prefix, anywhere), then the untranslated name, generic name, keywords,
  // category, description, and finally letters in order ("ffx" finds Firefox).
  function score(entry, text, q) {
    const name = text.name.toLowerCase()
    if (name === q) return 100
    if (name.startsWith(q)) return 90
    if (name.split(/[\s\-_.]+/).some(word => word.startsWith(q))) return 70
    if (name.includes(q)) return 60
    if (text.defaultName.toLowerCase().includes(q)) return 55
    if (text.genericName.toLowerCase().includes(q)) return 40
    if (text.keywords.some(keyword => keyword.toLowerCase().includes(q))) return 35
    if ((entry.categories ?? []).some(category => category.toLowerCase() === q)) return 30
    if (text.comment.toLowerCase().includes(q)) return 20

    let matched = 0
    for (const letter of name) {
      if (letter === q[matched]) matched++
      if (matched === q.length) return 10
    }
    return 0
  }

  // Visible applications matching the query, best first; alphabetical when
  // the query is empty.
  function search(query) {
    const entries = DesktopEntries.applications.values
      .filter(entry => !entry.noDisplay)
      .map(entry => ({ entry: entry, text: root.describe(entry) }))
    const q = query.trim().toLowerCase()
    if (q.length === 0) {
      return entries.sort((a, b) => a.text.name.localeCompare(b.text.name)).map(item => item.entry)
    }

    const scored = []
    for (const item of entries) {
      const s = root.score(item.entry, item.text, q)
      if (s > 0) scored.push({ entry: item.entry, name: item.text.name, score: s })
    }
    scored.sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
    return scored.map(item => item.entry)
  }

  // The name of the process an application runs, as opposed to its display
  // name: its executable (without directory), looking through an `env`
  // wrapper and `flatpak run`.
  function processName(entry) {
    const args = entry.command ?? []
    const base = path => path.split("/").pop()
    let i = 0
    if (args.length > 0 && base(args[0]) === "env") {
      i = 1
      while (i < args.length && (args[i].includes("=") || args[i].startsWith("-"))) {
        // -u NAME and -C DIR take a value of their own.
        i += ["-u", "--unset", "-C", "--chdir"].includes(args[i]) ? 2 : 1
      }
    }
    const exe = base(args[i] ?? "")
    if (exe === "flatpak") {
      const run = args.indexOf("run")
      const app = run >= 0 ? args.slice(run + 1).find(arg => !arg.startsWith("-")) : undefined
      if (app) return app
    }
    return exe.length > 0 ? exe : root.describe(entry).name
  }

  // The pointer rests on an application: show its tooltip once it stops
  // moving for a moment (and hide it while it moves).
  function hoverEntry(entry, point) {
    if (root.tipEntry !== entry) root.tipShown = false
    root.tipEntry = entry
    if (!root.tipShown) {
      root.tipX = point.x
      root.tipY = point.y
      tipTimer.restart()
    }
  }

  function leaveEntry() {
    tipTimer.stop()
    root.tipShown = false
    root.tipEntry = null
  }

  // ---- Files ----

  // Looks for files and folders named like the query in the home folder, a
  // moment after typing stops (fd, ignoring case; hidden and git-ignored ones
  // left out, as fd does): names containing it, or with a wildcard (* or ?)
  // in it, names matching it as a whole ("*.pdf", "rapport*"). The query goes to fd as an
  // argument, never into the command line itself. Its first output line is
  // the query it was for, so a search overtaken by typing is recognized.
  function searchFiles() {
    const q = root.query.trim()
    if (root.tab !== root.filesTab && root.tab !== root.allTab) return
    if (q === "") {
      root.fileResults = []
      root.fileResultsQuery = ""
      return
    }
    const mode = /[*?]/.test(q) ? "-g" : "-F"
    fileSearch.running = false
    fileSearch.command = ["sh", "-c",
      'printf "%s\\n" "$1"; fd "$2" -i -a -t d --max-results 30 -- "$1" "$HOME" | sed "s|/*$|/|"; fd "$2" -i -a -t f --max-results 80 -- "$1" "$HOME"',
      "sh", q, mode]
    fileSearch.running = true
  }

  function takeFiles(text) {
    const lines = text.split("\n")
    const q = lines.shift()
    if (q !== root.query.trim()) return
    const home = Quickshell.env("HOME")
    const wanted = q.toLowerCase()
    const items = lines.filter(line => line.length > 0).map(line => {
      const isDir = line.endsWith("/")
      const path = isDir ? line.slice(0, -1) : line
      const name = path.split("/").pop()
      const dir = path.slice(0, path.length - name.length - 1)
      const lower = name.toLowerCase()
      return {
        kind: "file", path: path, name: name, isDir: isDir,
        dir: dir.startsWith(home) ? "~" + dir.slice(home.length) : dir,
        rank: lower === wanted ? 0 : lower.startsWith(wanted) ? 1 : 2
      }
    })
    items.sort((a, b) => a.rank - b.rank || (b.isDir - a.isDir) || a.path.length - b.path.length || a.path.localeCompare(b.path))
    root.fileResults = items.slice(0, 60)
    root.fileResultsQuery = q
  }

  Timer {
    id: fileTimer
    interval: 120
    onTriggered: root.searchFiles()
  }

  Process {
    id: fileSearch
    stdout: StdioCollector {
      onStreamFinished: root.takeFiles(this.text)
    }
  }

  // ---- Web ----

  // What the web tab offers for `query`: the address, if it looks like one,
  // then a search with each engine of WebSearch.engines (set in the settings'
  // launcher category).
  function webResults(query) {
    const q = query.trim()
    if (q === "") return []
    const items = []
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(q) || (/^[^\s]+\.[a-z]{2,}(\/\S*)?$/i.test(q))) {
      const url = /^[a-z][a-z0-9+.-]*:\/\//i.test(q) ? q : "https://" + q
      items.push({ kind: "web", url: url, title: I18n.tr("launcher.web.open", q), subtitle: url, icon: "󰌷" })
    }
    for (const engine of WebSearch.engines) {
      items.push({
        kind: "web",
        url: engine.url.replace("%s", encodeURIComponent(q)),
        title: I18n.tr("launcher.web.search", engine.name, q),
        subtitle: engine.name,
        icon: engine.icon
      })
    }
    return items
  }

  function switchTab(index) {
    root.tab = (index + root.tabs.length) % root.tabs.length
    // A click sets the tab bar's own index (no longer bound): keep it right.
    tabBar.currentIndex = root.tab
    root.leaveEntry()
    list.currentIndex = root.firstSelectable()
    list.positionViewAtBeginning()
    if (root.tab === root.filesTab || root.tab === root.allTab) root.searchFiles()
  }

  // The applications tab's results.
  function appResults(query) {
    return root.search(query).map(entry => ({ kind: "app", entry: entry }))
  }

  // The all tab: with a query, the best applications, then files, then the
  // web (everything the web tab offers), each under its heading; without one,
  // just the applications (there's nothing to look for in files or on the
  // web).
  function allResults(query) {
    const q = query.trim()
    const apps = root.appResults(query)
    if (q === "") return apps
    const items = []
    const section = (title, list) => {
      if (list.length === 0) return
      items.push({ kind: "heading", title: title })
      for (const item of list) items.push(item)
    }
    section(I18n.tr("launcher.tab.apps"), apps.slice(0, root.allAppCount))
    section(I18n.tr("launcher.tab.files"), root.fileResultsQuery === q ? root.fileResults.slice(0, root.allFileCount) : [])
    section(I18n.tr("launcher.tab.web"), root.webResults(query))
    return items
  }

  // The first result that can be selected (not a heading), or 0.
  function firstSelectable() {
    const index = root.results.findIndex(item => item.kind !== "heading")
    return Math.max(0, index)
  }

  // Moves the selection by `delta` results, over any heading.
  function move(delta) {
    if (list.count === 0) return
    let index = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta))
    const step = delta > 0 ? 1 : -1
    while (root.results[index]?.kind === "heading") {
      const next = index + step
      if (next < 0 || next >= list.count) { index = list.currentIndex; break }
      index = next
    }
    list.currentIndex = index
  }

  // Opens the selected result: runs the application, opens the file or
  // folder with its default application, or the page in the browser.
  function launchCurrent() {
    if (list.currentIndex < 0 || list.currentIndex >= root.results.length) return
    const item = root.results[list.currentIndex]
    if (item.kind === "heading") return
    if (item.kind === "app") item.entry.execute()
    else Quickshell.execDetached(["xdg-open", item.kind === "file" ? item.path : item.url])
    LauncherState.visible = false
  }

  // Keys the search box doesn't use (Escape is handled by the panel).
  onKeyPressed: event => {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    const alt = (event.modifiers & Qt.AltModifier) !== 0
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      root.switchTab(root.tab + (event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1))
      event.accepted = true
    } else if (alt && event.key >= Qt.Key_1 && event.key < Qt.Key_1 + root.tabs.length) {
      root.switchTab(event.key - Qt.Key_1)
      event.accepted = true
    } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
      root.move(1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
      root.move(-1)
      event.accepted = true
    } else if (event.key === Qt.Key_PageDown) {
      root.move(8)
      event.accepted = true
    } else if (event.key === Qt.Key_PageUp) {
      root.move(-8)
      event.accepted = true
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    TabBar {
      id: tabBar
      model: root.tabs
      onCurrentIndexChanged: if (currentIndex !== root.tab) root.switchTab(currentIndex)
    }

    // Search box
    Rectangle {
      id: searchBox
      width: parent.width
      height: 44
      radius: Theme.radiusFor(height)
      color: Theme.backgroundColor
      border.color: Theme.outlineColor
      border.width: Theme.borderWidth

      ThemedText {
        id: searchIcon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍉"
        opacity: 0.7
      }

      TextInput {
        id: input
        anchors.left: searchIcon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.textColor
        selectionColor: Theme.accentColor
        selectedTextColor: Theme.backgroundColor
        font.family: Theme.fontFamily
        font.weight: Theme.fontWeight
        font.letterSpacing: Theme.fontLetterSpacing
        font.italic: Theme.fontItalic
        font.underline: Theme.fontUnderline
        font.pixelSize: Theme.fontSize()

        onTextChanged: {
          root.leaveEntry()
          root.query = input.text
          list.currentIndex = root.firstSelectable()
          list.positionViewAtBeginning()
          if (root.tab === root.filesTab || root.tab === root.allTab) fileTimer.restart()
        }
        onAccepted: root.launchCurrent()

        ThemedText {
          visible: input.text.length === 0
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr(["launcher.searchAll", "launcher.search", "launcher.searchFiles", "launcher.searchWeb"][root.tab])
          opacity: 0.5
        }
      }
    }

    // Results
    ListView {
      id: list
      width: parent.width
      height: parent.height - tabBar.height - searchBox.height - parent.spacing * 2
      clip: true
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0
      currentIndex: 0

      model: ScriptModel {
        values: root.results
      }

      delegate: Rectangle {
        id: entry

        required property var modelData
        required property int index
        readonly property bool current: ListView.isCurrentItem
        // A section's heading (the all tab): a title, never selected.
        readonly property bool heading: entry.modelData.kind === "heading"

        width: list.width
        height: entry.heading ? root.headingHeight : root.resultHeight
        radius: Theme.radiusFor(height)
        color: entry.current && !entry.heading ? Theme.accentColor : "transparent"

        ThemedText {
          visible: entry.heading
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          text: entry.modelData.title ?? ""
          color: Theme.accentColor
          sizeScale: 0.8
          font.bold: true
        }

        readonly property var app: entry.modelData.kind === "app" ? entry.modelData.entry : null

        // An application's icon; a glyph for a file, folder or web result.
        Item {
          id: icon
          visible: !entry.heading
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 32
          height: 32

          IconImage {
            visible: entry.app !== null
            anchors.fill: parent
            asynchronous: true
            source: entry.app ? Quickshell.iconPath(entry.app.icon, true) : ""
          }

          ThemedText {
            visible: entry.app === null
            anchors.centerIn: parent
            text: entry.modelData.kind === "file" ? (entry.modelData.isDir ? "󰉋" : "󰈔") : (entry.modelData.icon ?? "")
            sizeScale: 1.5
            color: entry.current ? Theme.backgroundColor : Theme.accentColor
          }
        }

        Column {
          visible: !entry.heading
          anchors.left: icon.right
          anchors.leftMargin: 12
          anchors.right: showInFiles.visible ? showInFiles.left : parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          ThemedText {
            width: parent.width
            elide: Text.ElideRight
            text: entry.app ? root.describe(entry.app).name : entry.modelData.kind === "file" ? entry.modelData.name : entry.modelData.title
            color: entry.current ? Theme.backgroundColor : Theme.textColor
          }

          ThemedText {
            visible: text.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: entry.app ? (root.describe(entry.app).comment || root.describe(entry.app).genericName)
              : entry.modelData.kind === "file" ? entry.modelData.dir : entry.modelData.subtitle
            color: entry.current ? Theme.backgroundColor : Theme.textColor
            opacity: 0.6
            sizeScale: 0.7
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: !entry.heading
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          // Follow real mouse movement only: while scrolling with the
          // keys, entries slide under a still pointer and must not steal
          // the selection.
          onPositionChanged: mouse => {
            list.currentIndex = entry.index
            // The tooltip (the real process name) is an application's only.
            if (entry.app) root.hoverEntry(entry.app, mapToItem(root.panel, mouse.x, mouse.y))
          }
          onExited: root.leaveEntry()
          onClicked: {
            list.currentIndex = entry.index
            root.launchCurrent()
          }
        }

        // A file or folder: show it in Nautilus (the file selected in its
        // folder; a folder opened), rather than opening it.
        IconButton {
          id: showInFiles
          visible: entry.modelData.kind === "file"
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰉋"
          sizeScale: 1.2
          // On the selected row's accent background: in its text color,
          // dimmed until hovered.
          color: entry.current ? Theme.backgroundColor : Theme.textColor
          hoverColor: entry.current ? Theme.backgroundColor : Theme.accentColor
          opacity: entry.current && !hovered ? 0.7 : 1
          onClicked: {
            Quickshell.execDetached(entry.modelData.isDir ? ["nautilus", entry.modelData.path] : ["nautilus", "--select", entry.modelData.path])
            LauncherState.visible = false
          }
        }
      }

      onContentYChanged: root.leaveEntry()

      ThemedText {
        visible: list.count === 0
        anchors.centerIn: parent
        text: I18n.tr(root.query.trim() === "" && root.tab === root.filesTab ? "launcher.filesHint"
          : root.query.trim() === "" && root.tab === root.webTab ? "launcher.webHint"
          : root.filesPending ? "launcher.searching" : "launcher.noResults")
        opacity: 0.6
      }
    }
  }

  Timer {
    id: tipTimer
    interval: 500
    onTriggered: root.tipShown = true
  }

  // Tooltip with the real process name of the hovered application.
  Rectangle {
    id: tooltip

    readonly property real maxTextWidth: Math.min(420, root.panel.width - 48)

    visible: root.tipShown && root.tipEntry !== null
    z: 10
    width: tipText.width + 20
    height: tipText.implicitHeight + 14
    // Just below the pointer, kept inside the panel; above it when there's
    // no room underneath.
    x: Math.max(8, Math.min(root.tipX + 12, root.panel.width - width - 8))
    y: root.tipY + 24 + height > root.panel.height - 8 ? root.tipY - height - 12 : root.tipY + 24
    radius: Theme.radiusFor(height)
    color: Theme.backgroundColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth

    Column {
      id: tipText
      x: 10
      y: 7
      spacing: 2

      ThemedText {
        width: Math.min(implicitWidth, tooltip.maxTextWidth)
        elide: Text.ElideRight
        text: root.tipEntry ? root.processName(root.tipEntry) : ""
        color: Theme.accentColor
      }

      ThemedText {
        width: Math.min(implicitWidth, tooltip.maxTextWidth)
        elide: Text.ElideRight
        text: root.tipEntry ? (root.tipEntry.command ?? []).join(" ") : ""
        opacity: 0.7
        sizeScale: 0.75
      }

      ThemedText {
        width: Math.min(implicitWidth, tooltip.maxTextWidth)
        elide: Text.ElideRight
        text: root.tipEntry ? root.tipEntry.id + (root.tipEntry.runInTerminal ? " · " + I18n.tr("launcher.terminal") : "") : ""
        opacity: 0.5
        sizeScale: 0.65
      }
    }
  }
}
