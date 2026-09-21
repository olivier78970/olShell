import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// Application launcher, toggled from outside via:
//   quickshell -p . ipc call launcher toggle
// or from the bar's launcher icon. Type to filter the installed
// applications, Up/Down (or Tab, Ctrl+N/P) to move, Enter to launch, Escape
// to close.
ModalPanel {
  id: root

  property string query: ""
  readonly property var results: root.search(root.query)

  // The application whose tooltip is (about to be) shown, where the pointer
  // was (in panel coordinates), and whether it's visible yet.
  property var tipEntry: null
  property real tipX: 0
  property real tipY: 0
  property bool tipShown: false

  maxPanelWidth: 640
  maxPanelHeight: 520
  focusTarget: input

  visible: LauncherState.visible
  onCloseRequested: LauncherState.visible = false
  onOpened: {
    input.text = ""
    list.currentIndex = 0
    root.leaveEntry()
    // Pick up applications installed since the last look.
    DesktopLocale.refresh()
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

  function move(delta) {
    if (list.count === 0) return
    list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + delta))
  }

  function launchCurrent() {
    if (list.currentIndex < 0 || list.currentIndex >= root.results.length) return
    root.results[list.currentIndex].execute()
    LauncherState.visible = false
  }

  // Keys the search box doesn't use (Escape is handled by the panel).
  onKeyPressed: event => {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) {
      root.move(1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) {
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
          list.currentIndex = 0
          list.positionViewAtBeginning()
        }
        onAccepted: root.launchCurrent()

        ThemedText {
          visible: input.text.length === 0
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("launcher.search")
          opacity: 0.5
        }
      }
    }

    // Results
    ListView {
      id: list
      width: parent.width
      height: parent.height - searchBox.height - parent.spacing
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

        width: list.width
        height: 52
        radius: Theme.radiusFor(height)
        color: entry.current ? Theme.accentColor : "transparent"

        IconImage {
          id: icon
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 32
          height: 32
          asynchronous: true
          source: Quickshell.iconPath(entry.modelData.icon, true)
        }

        Column {
          anchors.left: icon.right
          anchors.leftMargin: 12
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1

          ThemedText {
            width: parent.width
            elide: Text.ElideRight
            text: root.describe(entry.modelData).name
            color: entry.current ? Theme.backgroundColor : Theme.textColor
          }

          ThemedText {
            visible: text.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: root.describe(entry.modelData).comment || root.describe(entry.modelData).genericName
            color: entry.current ? Theme.backgroundColor : Theme.textColor
            opacity: 0.6
            sizeScale: 0.7
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          // Follow real mouse movement only: while scrolling with the
          // keys, entries slide under a still pointer and must not steal
          // the selection.
          onPositionChanged: mouse => {
            list.currentIndex = entry.index
            root.hoverEntry(entry.modelData, mapToItem(root.panel, mouse.x, mouse.y))
          }
          onExited: root.leaveEntry()
          onClicked: {
            list.currentIndex = entry.index
            root.launchCurrent()
          }
        }
      }

      onContentYChanged: root.leaveEntry()

      ThemedText {
        visible: list.count === 0
        anchors.centerIn: parent
        text: I18n.tr("launcher.noResults")
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
