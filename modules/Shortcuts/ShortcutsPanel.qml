import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The shortcuts of the Hyprland config that use the Super key (keyboard and
// mouse), centered on the screen like the launcher, toggled from outside via:
//   quickshell -p . ipc call shortcuts toggle
// Read from the config each time it opens (scripts/list-shortcuts.py), so a
// shortcut just added shows, grouped by kind and described in the shell's
// language. Type to filter them;
// Up/Down/PageUp/PageDown scroll, Escape closes.
ModalPanel {
  id: root

  // What the script found: the shortcuts, and how many binds with Super
  // Hyprland has (to say when some couldn't be read).
  property var shortcuts: []
  property int running: -1
  property bool loading: false
  property string query: ""

  // The rows to show: a heading before each group, then its shortcuts,
  // filtered by the search text.
  readonly property var rows: {
    const words = root.query.toLowerCase().split(/\s+/).filter(word => word.length > 0)
    const groups = {}
    for (const shortcut of root.shortcuts) {
      const text = [root.keysText(shortcut), root.describe(shortcut), shortcut.command ?? ""].join(" ").toLowerCase()
      if (!words.every(word => text.includes(word))) continue
      const category = root.categoryOf(shortcut)
      ;(groups[category] = groups[category] ?? []).push(shortcut)
    }
    const rows = []
    for (const category of root.categories) {
      if (!groups[category]) continue
      rows.push({ heading: I18n.tr("shortcuts.category." + category) })
      for (const shortcut of groups[category]) rows.push({ shortcut: shortcut })
    }
    return rows
  }

  readonly property var categories: ["apps", "shell", "windows", "workspaces", "other"]

  maxPanelWidth: 820
  maxPanelHeight: 680
  focusTarget: input

  open: ShortcutsPanelState.visible
  onCloseRequested: ShortcutsPanelState.visible = false
  onOpened: {
    input.text = ""
    list.positionViewAtBeginning()
    root.loading = true
    reader.running = true
  }

  IpcHandler {
    target: "shortcuts"

    function toggle(): void {
      ShortcutsPanelState.toggle()
    }
  }

  // Read again at each opening, so a config just edited shows.
  Process {
    id: reader
    command: ["python3", Paths.listShortcutsScript]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const result = JSON.parse(this.text)
          root.shortcuts = result.shortcuts
          root.running = result.running
        } catch (e) {
          root.shortcuts = []
          root.running = -1
        }
        root.loading = false
      }
    }
  }

  function categoryOf(shortcut) {
    switch (shortcut.action) {
    case "exec": return "apps"
    case "shell": return "shell"
    case "close": case "float": case "fullscreen": case "drag": case "resize": case "focusDirection": return "windows"
    case "focusWorkspace": case "moveToWorkspace": case "nextWorkspace": case "previousWorkspace": case "toggleSpecial": return "workspaces"
    default: return "other"
    }
  }

  // A key's label: as the script gives it, but for the mouse ones ("@...").
  function keyLabel(key) {
    return key.startsWith("@") ? I18n.tr("shortcuts.key." + key.slice(1)) : key
  }

  function keysText(shortcut) {
    return shortcut.keys.map(key => root.keyLabel(key)).join(" + ")
  }

  // What a shortcut does, in the shell's language: its own description if
  // the config gives one.
  function describe(shortcut) {
    if (shortcut.description) return shortcut.description
    switch (shortcut.action) {
    case "exec":
      return I18n.tr("shortcuts.exec", shortcut.arg)
    case "shell": {
      const key = "shortcuts.shell." + shortcut.arg
      const text = I18n.tr(key, shortcut.value)
      return text !== key ? text : I18n.tr("shortcuts.shell", shortcut.arg.replace(".", " ") + (shortcut.value ? " " + shortcut.value : ""))
    }
    case "focusDirection":
      return I18n.tr("shortcuts.focusDirection." + shortcut.arg)
    case "other":
      return shortcut.arg
    default:
      return I18n.tr("shortcuts." + shortcut.action, shortcut.arg ?? "")
    }
  }

  // Keys the search box doesn't use (Escape is handled by the panel).
  onKeyPressed: event => {
    const step = event.key === Qt.Key_Down ? 60 : event.key === Qt.Key_Up ? -60
      : event.key === Qt.Key_PageDown ? list.height * 0.9 : event.key === Qt.Key_PageUp ? -list.height * 0.9 : 0
    if (step === 0) return
    list.contentY = Math.max(0, Math.min(list.contentHeight - list.height, list.contentY + step))
    event.accepted = true
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    ThemedText {
      id: title
      text: I18n.tr("shortcuts.title")
      sizeScale: 1.2
      font.bold: true
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
          root.query = input.text
          list.positionViewAtBeginning()
        }

        ThemedText {
          visible: input.text.length === 0
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("shortcuts.search")
          opacity: 0.5
        }
      }
    }

    ListView {
      id: list
      width: parent.width
      height: parent.height - title.height - searchBox.height - (note.visible ? note.height + parent.spacing : 0) - parent.spacing * 2
      clip: true
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds

      model: ScriptModel {
        values: root.rows
      }

      delegate: Item {
        id: row

        required property var modelData
        readonly property bool heading: row.modelData.heading !== undefined
        readonly property var shortcut: row.modelData.shortcut ?? null

        width: list.width
        height: row.heading ? 34 : Math.max(40, details.implicitHeight + 12)

        // A group's heading.
        ThemedText {
          visible: row.heading
          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          text: row.modelData.heading ?? ""
          color: Theme.accentColor
          sizeScale: 0.85
          font.bold: true
        }

        // A shortcut: its keys as keycaps, then what it does.
        Rectangle {
          visible: !row.heading
          anchors.fill: parent
          radius: Theme.radiusFor(height)
          color: hover.hovered ? Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.06) : "transparent"

          HoverHandler {
            id: hover
          }

          Row {
            id: keycaps
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 280
            spacing: 4

            Repeater {
              model: row.shortcut ? row.shortcut.keys : []

              Rectangle {
                required property string modelData

                width: keyText.implicitWidth + 14
                height: keyText.implicitHeight + 6
                radius: Math.min(6, height / 2)
                color: Theme.backgroundColor
                border.color: Theme.outlineColor
                border.width: 1

                ThemedText {
                  id: keyText
                  anchors.centerIn: parent
                  text: root.keyLabel(parent.modelData)
                  sizeScale: 0.8
                }
              }
            }
          }

          Column {
            id: details
            anchors.left: keycaps.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            ThemedText {
              width: parent.width
              elide: Text.ElideRight
              text: row.shortcut ? root.describe(row.shortcut) : ""
            }

            // The command a program is started with, when there's more to it.
            ThemedText {
              visible: text.length > 0
              width: parent.width
              elide: Text.ElideRight
              text: row.shortcut && row.shortcut.action === "exec" && row.shortcut.command !== row.shortcut.arg ? row.shortcut.command : ""
              sizeScale: 0.75
              opacity: 0.55
            }
          }
        }
      }

      // Nothing to show.
      ThemedText {
        visible: list.count === 0
        anchors.centerIn: parent
        text: I18n.tr(root.loading ? "shortcuts.loading" : root.shortcuts.length === 0 ? "shortcuts.none" : "shortcuts.empty")
        opacity: 0.6
      }
    }

    // Some of Hyprland's binds couldn't be read from its config.
    ThemedText {
      id: note
      visible: !root.loading && root.running > root.shortcuts.length
      width: parent.width
      wrapMode: Text.WordWrap
      text: I18n.tr("shortcuts.missing", root.running - root.shortcuts.length, root.running)
      sizeScale: 0.8
      opacity: 0.6
    }
  }
}
