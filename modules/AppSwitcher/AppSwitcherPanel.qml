import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config

// The app switcher: Hyprland's windows, the most recently focused first,
// in a column or side by side (Settings.switcherOrientation), placed like
// the other panels (Settings.switcherPlacement), opened from
// outside via:
//   quickshell -p . ipc call switcher toggle
// bound to a shortcut in the Hyprland config (such as Super+Tab), which it
// then follows (AppSwitcherState.shortcut): it opens on the previously
// focused window, the shortcut pressed again moves on (with Shift, back),
// and releasing its modifier switches to the selected window. `switcher
// next` / `switcher prev` step the same way. Up/Down, Tab / Shift+Tab (or
// Left/Right) move too, Enter or a click switches to the window (so does
// `switcher confirm`), Escape closes.
ModalPanel {
  id: root

  // Hyprland's windows, as `hyprctl clients -j` gives them, the most
  // recently focused first.
  property var windows: []
  property bool loading: false

  // The selected window's index in `windows` (AppSwitcherState.current
  // taken modulo their number), or -1 with none.
  readonly property int selected: root.windows.length > 0
    ? ((AppSwitcherState.current % root.windows.length) + root.windows.length) % root.windows.length
    : -1

  // Whether the windows are side by side, as cards, rather than in a column
  // of rows.
  readonly property bool horizontal: Settings.switcherOrientation === "horizontal"
  // The windows shown at most before the list scrolls: rows in a column,
  // cards side by side.
  readonly property int maxRows: 8
  readonly property int maxCards: 6
  readonly property int rowHeight: 56
  // A card: its width, and its height (its icon, and a line of each text
  // size under it, measured by the probes below).
  readonly property int cardWidth: 168
  readonly property int cardIcon: 48
  readonly property real cardHeight: 14 + root.cardIcon + 10 + titleProbe.implicitHeight + detailsProbe.implicitHeight + 14
  // How many windows there is room for (at least one, for the messages).
  readonly property int shown: Math.max(root.windows.length, 1)

  // As wide as its cards side by side (up to maxCards; no narrower than
  // the title needs), or a fixed width for rows; as tall as its rows (up to
  // maxRows) or its cards.
  maxPanelWidth: root.horizontal
    ? Math.max(16 * 2 + Math.min(root.shown, root.maxCards) * (root.cardWidth + list.spacing) - list.spacing, title.implicitWidth + 16 * 2)
    : 640
  maxPanelHeight: 16 * 2 + title.implicitHeight + 12
    + (root.horizontal ? root.cardHeight : Math.min(root.shown, root.maxRows) * (root.rowHeight + list.spacing))
  placement: Settings.switcherPlacement
  focusTarget: keys

  open: AppSwitcherState.visible
  onCloseRequested: AppSwitcherState.visible = false
  onOpened: {
    root.loading = true
    reader.running = true
  }

  // Switches to window `index` and closes.
  function activate(index) {
    const window = root.windows[index]
    AppSwitcherState.visible = false
    if (window) Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:" + window.address) + " })")
  }

  // A window's icon: its desktop entry's (a theme icon, or a file for an
  // absolute path), or else one named after its class; "" when the icon
  // theme has neither (as in the bar's window title).
  function iconOf(window) {
    const entry = DesktopEntries.byId(window.class)
    const icon = entry ? entry.icon : ""
    if (icon.startsWith("/")) return "file://" + icon
    if (icon !== "") return Quickshell.iconPath(icon, true)
    return Quickshell.iconPath(window.class, true) || Quickshell.iconPath(window.class.toLowerCase(), true)
  }

  Connections {
    target: AppSwitcherState

    function onConfirmRequested() {
      root.activate(root.selected)
    }
  }

  // Read at each opening, for the windows and their focus order.
  Process {
    id: reader
    command: ["hyprctl", "clients", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.windows = JSON.parse(this.text)
            .filter(window => window.mapped && !window.hidden)
            .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
        } catch (e) {
          root.windows = []
        }
        root.loading = false
      }
    }
  }

  // The Qt keys a key of the shortcut (as list-shortcuts.py names it) can
  // come as: the modifiers' left and right keys, and the named keys; a
  // single character is its own code (upper case, as Qt's keys are).
  function qtKeys(name) {
    switch (name) {
    case "Super": return [Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R]
    case "Alt": return [Qt.Key_Alt]
    case "AltGr": return [Qt.Key_AltGr]
    case "Ctrl": return [Qt.Key_Control]
    case "Shift": return [Qt.Key_Shift]
    case "Tab": return [Qt.Key_Tab, Qt.Key_Backtab]
    case "Space": return [Qt.Key_Space]
    case "Enter": return [Qt.Key_Return, Qt.Key_Enter]
    default: return name.length === 1 ? [name.toUpperCase().charCodeAt(0)] : []
    }
  }

  // The keys whose release switches to the selected window: the shortcut's
  // modifiers, or while it isn't known, Super, Alt and Ctrl.
  readonly property var releaseKeys: (AppSwitcherState.modifiers.length > 0 ? AppSwitcherState.modifiers : ["Super", "Alt", "Ctrl"])
    .reduce((keys, name) => keys.concat(root.qtKeys(name)), [])

  onKeyPressed: event => {
    // The shortcut's key reaching the panel (Hyprland takes the shortcut
    // itself, but not with Shift added): back with Shift, on otherwise.
    if (AppSwitcherState.key !== "" && root.qtKeys(AppSwitcherState.key).includes(event.key)) {
      AppSwitcherState.current += (event.modifiers & Qt.ShiftModifier) ? -1 : 1
      event.accepted = true
    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
      AppSwitcherState.current += 1
      event.accepted = true
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
      AppSwitcherState.current -= 1
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activate(root.selected)
      event.accepted = true
    }
  }

  // Holds the keyboard: the keys pressed go on to the frame (and
  // onKeyPressed above), and the release of the shortcut's modifier while
  // cycling switches to the selected window.
  Item {
    id: keys
    focus: true

    Keys.onReleased: event => {
      if (AppSwitcherState.cycling && root.releaseKeys.includes(event.key) && !event.isAutoRepeat) {
        root.activate(root.selected)
        event.accepted = true
      }
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    ThemedText {
      id: title
      anchors.horizontalCenter: parent.horizontalCenter
      text: I18n.tr("switcher.title")
      sizeScale: 1.2
      font.bold: true
    }

    // A line of each text size of a card, measured for its height; never shown.
    ThemedText {
      id: titleProbe
      visible: false
      text: "Ag"
    }

    ThemedText {
      id: detailsProbe
      visible: false
      text: "Ag"
      sizeScale: 0.75
    }

    ListView {
      id: list
      width: parent.width
      height: parent.height - title.height - parent.spacing
      orientation: root.horizontal ? ListView.Horizontal : ListView.Vertical
      clip: true
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      currentIndex: root.selected
      highlightFollowsCurrentItem: false

      // Keeps the selected window in view.
      onCurrentIndexChanged: if (list.currentIndex >= 0) list.positionViewAtIndex(list.currentIndex, ListView.Contain)

      model: ScriptModel {
        values: root.windows
      }

      delegate: Rectangle {
        id: entry

        required property var modelData
        required property int index
        readonly property bool current: entry.index === root.selected
        readonly property string iconSource: root.iconOf(entry.modelData)

        width: root.horizontal ? root.cardWidth : list.width
        height: root.horizontal ? list.height : root.rowHeight
        radius: Theme.radiusFor(root.horizontal ? root.rowHeight : height)
        color: entry.current ? Theme.accentColor
          : hover.hovered ? Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.06) : "transparent"

        HoverHandler {
          id: hover
        }

        TapHandler {
          onTapped: root.activate(entry.index)
        }

        // Before the texts in a row, above them on a card.
        IconImage {
          id: icon
          visible: entry.iconSource !== "" && icon.status !== Image.Error
          x: root.horizontal ? (parent.width - width) / 2 : 12
          y: root.horizontal ? 14 : (parent.height - height) / 2
          width: root.horizontal ? root.cardIcon : 32
          height: width
          source: entry.iconSource
        }

        // The generic glyph, where there's no icon to show (as in the bar's
        // window title and the launcher).
        ThemedText {
          visible: !icon.visible
          anchors.centerIn: icon
          text: "󰀻"
          sizeScale: root.horizontal ? 2.2 : 1.4
          color: entry.current ? Theme.backgroundColor : Theme.textColor
        }

        Column {
          x: root.horizontal ? 10 : icon.x + icon.width + 12
          y: root.horizontal ? icon.y + icon.height + 10 : (parent.height - height) / 2
          width: root.horizontal ? parent.width - 20 : parent.width - x - 12
          spacing: root.horizontal ? 0 : 1

          ThemedText {
            width: parent.width
            horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            text: entry.modelData.title || entry.modelData.class
            color: entry.current ? Theme.backgroundColor : Theme.textColor
          }

          // Its app and workspace.
          ThemedText {
            width: parent.width
            horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            text: I18n.tr("switcher.details", entry.modelData.class, entry.modelData.workspace?.name ?? "")
            color: entry.current ? Theme.backgroundColor : Theme.textColor
            sizeScale: 0.75
            opacity: 0.7
          }
        }
      }

      // Nothing to show.
      ThemedText {
        visible: list.count === 0
        anchors.centerIn: parent
        text: I18n.tr(root.loading ? "switcher.loading" : "switcher.empty")
        opacity: 0.6
      }
    }
  }
}
