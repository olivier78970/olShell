import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// Every emoji, by Unicode's groups, centered on the screen or against the bar
// (Settings.emojiPlacement), toggled from outside via:
//   quickshell -p . ipc call emoji toggle
// Picking one (a click, or Enter on the selected one) copies it to the
// clipboard and closes the panel; the copied ones are kept in a "recent"
// group until the shell restarts (EmojiPanelState). Type to search every
// group by the emoji's names and keywords in the shell's language (accents
// don't count); the arrows move the selection, Tab and Shift+Tab change group,
// Escape closes.
ModalPanel {
  id: root

  // Every emoji as { group, emoji, name, search }, in Unicode's order, named
  // in the shell's language (Paths.emojiData), `search` being its name and
  // keywords as searched (see searchText()).
  property var all: []
  // Each emoji's name, by the emoji, for the recent ones.
  property var names: ({})
  property string query: ""

  // The groups' ids, in order, and the emoji standing for each on its tab.
  readonly property var groups: ["recent", "smileys", "people", "animals", "food", "travel", "activities", "objects", "symbols", "flags"]
  readonly property var groupIcons: ({
    recent: "🕘", smileys: "😀", people: "👋", animals: "🐻", food: "🍔",
    travel: "✈️", activities: "⚽", objects: "💡", symbols: "🔣", flags: "🏁"
  })

  // The emoji to show: those whose name has every word typed, from every
  // group, or else those of the group picked.
  readonly property var shown: {
    const words = root.searchText(root.query).split(/\s+/).filter(word => word.length > 0)
    if (words.length > 0) return root.all.filter(entry => words.every(word => entry.search.includes(word)))
    if (EmojiPanelState.group === "recent")
      return EmojiPanelState.recent.map(emoji => ({ group: "recent", emoji: emoji, name: root.names[emoji] ?? "" }))
    return root.all.filter(entry => entry.group === EmojiPanelState.group)
  }
  // The emoji selected, or null.
  readonly property var current: grid.currentIndex >= 0 && grid.currentIndex < root.shown.length ? root.shown[grid.currentIndex] : null

  maxPanelWidth: 640
  maxPanelHeight: 600
  placement: Settings.emojiPlacement
  focusTarget: input

  open: EmojiPanelState.visible
  onCloseRequested: EmojiPanelState.visible = false
  onOpened: {
    input.text = ""
    grid.currentIndex = 0
    grid.positionViewAtBeginning()
  }

  // `text` as the search compares it: lower case, without accents, and œ
  // and æ written oe and ae (so "coeur" finds "cœur").
  function searchText(text) {
    return text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/œ/g, "oe").replace(/æ/g, "ae")
  }

  // Read when the panel is built, and again if the language changes.
  FileView {
    path: Paths.emojiData(I18n.supported.includes(I18n.language) ? I18n.language : I18n.fallback)
    onLoaded: {
      const all = []
      const names = {}
      for (const line of this.text().split("\n")) {
        if (line.length === 0 || line.startsWith("#")) continue
        const [group, emoji, name, keywords] = line.split("\t")
        all.push({ group: group, emoji: emoji, name: name, search: root.searchText(name + " " + keywords.replace(/,/g, " ")) })
        names[emoji] = name
      }
      root.all = all
      root.names = names
    }
  }

  // Copies `emoji` and closes the panel.
  function pick(emoji) {
    EmojiPanelState.copy(emoji)
    EmojiPanelState.visible = false
  }

  // Shows the group `step` places after the one shown (before it when
  // negative), leaving a search.
  function changeGroup(step) {
    const index = root.groups.indexOf(EmojiPanelState.group)
    root.showGroup(root.groups[(index + step + root.groups.length) % root.groups.length])
  }

  function showGroup(group) {
    input.text = ""
    EmojiPanelState.group = group
    grid.currentIndex = 0
    grid.positionViewAtBeginning()
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    ThemedText {
      id: title
      text: I18n.tr("emoji.title")
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
          grid.currentIndex = 0
          grid.positionViewAtBeginning()
        }

        // The arrows move the grid's selection rather than the cursor.
        Keys.onPressed: event => {
          switch (event.key) {
          case Qt.Key_Left: grid.moveCurrentIndexLeft(); break
          case Qt.Key_Right: grid.moveCurrentIndexRight(); break
          case Qt.Key_Up: grid.moveCurrentIndexUp(); break
          case Qt.Key_Down: grid.moveCurrentIndexDown(); break
          case Qt.Key_Tab: root.changeGroup(1); break
          case Qt.Key_Backtab: root.changeGroup(-1); break
          case Qt.Key_Return:
          case Qt.Key_Enter:
            if (root.current) root.pick(root.current.emoji)
            break
          default: return
          }
          event.accepted = true
        }

        ThemedText {
          visible: input.text.length === 0
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("emoji.search")
          opacity: 0.5
        }
      }
    }

    // One tab per group, dimmed while a search shows every group.
    Row {
      id: tabs
      width: parent.width
      spacing: 4
      opacity: root.query.length > 0 ? 0.5 : 1

      Repeater {
        model: root.groups

        Rectangle {
          id: tab

          required property string modelData
          readonly property bool picked: root.query.length === 0 && EmojiPanelState.group === tab.modelData

          width: (tabs.width - tabs.spacing * (root.groups.length - 1)) / root.groups.length
          height: 38
          radius: Theme.radiusFor(height)
          color: tab.picked ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.22)
            : tabArea.containsMouse ? Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.06) : "transparent"
          border.color: tab.picked ? Theme.accentColor : "transparent"
          border.width: Theme.borderWidth

          Text {
            anchors.centerIn: parent
            text: root.groupIcons[tab.modelData]
            font.pixelSize: 20
          }

          MouseArea {
            id: tabArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showGroup(tab.modelData)
          }
        }
      }
    }

    // The group's name, or how many emoji the search found.
    ThemedText {
      id: heading
      text: root.query.length > 0 ? I18n.tr("emoji.results", root.shown.length) : I18n.tr("emoji.group." + EmojiPanelState.group)
      color: Theme.accentColor
      sizeScale: 0.85
      font.bold: true
    }

    GridView {
      id: grid

      // As many columns as fit, sharing the width.
      readonly property int columns: Math.max(1, Math.floor(width / 52))

      width: parent.width
      height: parent.height - title.height - searchBox.height - tabs.height - heading.height - footer.height - parent.spacing * 5
      clip: true
      cellWidth: width / columns
      cellHeight: 52
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0

      model: ScriptModel {
        values: root.shown
      }

      delegate: Rectangle {
        id: cell

        required property var modelData
        required property int index
        readonly property bool current: GridView.isCurrentItem

        width: grid.cellWidth - 4
        height: grid.cellHeight - 4
        radius: Theme.radiusFor(height)
        color: cell.current ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.22) : "transparent"
        border.color: cell.current ? Theme.accentColor : "transparent"
        border.width: Theme.borderWidth

        Text {
          anchors.centerIn: parent
          text: cell.modelData.emoji
          font.pixelSize: 28
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: grid.currentIndex = cell.index
          onClicked: root.pick(cell.modelData.emoji)
        }
      }

      // Nothing to show.
      ThemedText {
        visible: grid.count === 0
        anchors.centerIn: parent
        text: I18n.tr(root.query.length === 0 && EmojiPanelState.group === "recent" ? "emoji.noRecent" : "emoji.empty")
        opacity: 0.6
      }
    }

    // The selected emoji's name, and what the keys do.
    Item {
      id: footer
      width: parent.width
      height: Math.max(name.implicitHeight, hint.implicitHeight)

      ThemedText {
        id: name
        anchors.left: parent.left
        anchors.right: hint.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.current ? root.current.name : ""
      }

      ThemedText {
        id: hint
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr("emoji.hint")
        sizeScale: 0.8
        opacity: 0.6
      }
    }
  }
}
