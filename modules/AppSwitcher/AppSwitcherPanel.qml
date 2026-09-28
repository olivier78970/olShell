import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
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
// and releasing its modifier switches to the selected window
// (Settings.switcherReleaseSwitch). `switcher next` / `switcher prev` step
// the same way. Up/Down, Tab / Shift+Tab (or Left/Right) move too, Enter or
// a click switches to the window (so does `switcher confirm`), Escape
// closes. It lists every window, or those of the focused workspace or
// monitor (Settings.switcherScope), each on its own or gathered by app
// (Settings.switcherGroupApps), the key above Tab then going through the
// selected app's windows.
ModalPanel {
  id: root

  // Hyprland's windows, as `hyprctl clients -j` gives them, the most
  // recently focused first, those Settings.switcherScope leaves out left out.
  property var windows: []
  property bool loading: false

  // What the list shows: one entry per window, or with switcherGroupApps
  // one per app, each { class, windows } (its windows the most recently
  // focused first; the entries in the order of their first window).
  readonly property var entries: {
    if (!Settings.switcherGroupApps) return root.windows.map(window => ({ class: window.class, windows: [window] }))
    const entries = []
    for (const window of root.windows) {
      const entry = entries.find(other => other.class === window.class)
      if (entry) entry.windows.push(window)
      else entries.push({ class: window.class, windows: [window] })
    }
    return entries
  }

  // The selected entry's index (AppSwitcherState.current taken modulo their
  // number), or -1 with none.
  readonly property int selected: root.entries.length > 0
    ? ((AppSwitcherState.current % root.entries.length) + root.entries.length) % root.entries.length
    : -1
  // Which of the selected app's windows is picked (any number, taken modulo
  // theirs): the most recently focused, until the key above Tab moves on.
  property int inner: 0
  onSelectedChanged: root.inner = 0

  // Whether the windows are side by side, as cards, rather than in a column
  // of rows, and whether those cards show a picture of their window.
  readonly property bool horizontal: Settings.switcherOrientation === "horizontal"
  readonly property bool previews: root.horizontal && Settings.switcherPreviews
  // The entries shown at most before the list scrolls, and how many there
  // is room for (at least one, for the messages).
  readonly property int maxShown: Settings.switcherMaxShown
  readonly property int shown: Math.max(root.entries.length, 1)
  readonly property int iconSize: Settings.switcherIconSize
  readonly property real rowHeight: root.iconSize + 24
  // A card's picture (its window's, or its icon) and the card itself: the
  // picture, then a line of each text size, measured by the probes below.
  readonly property real mediaWidth: root.previews ? 240 : root.iconSize
  readonly property real mediaHeight: root.previews ? 150 : root.iconSize
  readonly property real cardWidth: Math.max(140, root.mediaWidth + 20, root.iconSize + 100)
  readonly property real cardHeight: 14 + root.mediaHeight + 10 + titleProbe.implicitHeight + detailsProbe.implicitHeight + 14

  // As wide as its cards side by side (up to maxShown; no narrower than
  // the title needs), or a fixed width for rows; as tall as its rows (up to
  // maxShown) or its cards.
  maxPanelWidth: root.horizontal
    ? Math.max(16 * 2 + Math.min(root.shown, root.maxShown) * (root.cardWidth + list.spacing) - list.spacing, title.implicitWidth + 16 * 2)
    : 640
  maxPanelHeight: 16 * 2 + title.implicitHeight + 12
    + (root.horizontal ? root.cardHeight : Math.min(root.shown, root.maxShown) * (root.rowHeight + list.spacing))
  placement: Settings.switcherPlacement
  focusTarget: keys

  open: AppSwitcherState.visible
  onCloseRequested: AppSwitcherState.visible = false
  onOpened: {
    root.loading = true
    reader.running = true
  }

  // The window entry `index` switches to: the picked one of the selected
  // entry, the most recently focused of another.
  function windowOf(index) {
    const entry = root.entries[index]
    if (!entry) return null
    const count = entry.windows.length
    return index === root.selected ? entry.windows[((root.inner % count) + count) % count] : entry.windows[0]
  }

  // Switches to entry `index`'s window and closes.
  function activate(index) {
    const window = root.windowOf(index)
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

  // A window's Wayland toplevel, to capture its picture (Hyprland gives
  // addresses with or without the "0x").
  function toplevelOf(window) {
    const address = window.address.replace(/^0x/, "")
    const toplevel = Hyprland.toplevels.values.find(other => other.address.replace(/^0x/, "") === address)
    return toplevel?.wayland ?? null
  }

  // What's said under a window's title: its app, then its workspace and, for
  // an app's entry, how many windows it has.
  function detailsOf(entry, window) {
    const parts = [entry.class]
    if (Settings.switcherShowWorkspace && window.workspace?.name) parts.push(I18n.tr("switcher.workspace", window.workspace.name))
    if (entry.windows.length > 1) parts.push(I18n.tr("switcher.windows", entry.windows.length))
    return parts.join("  ·  ")
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
        const workspace = Hyprland.focusedWorkspace?.id
        const monitor = Hyprland.focusedMonitor?.id
        try {
          root.windows = JSON.parse(this.text)
            .filter(window => window.mapped && !window.hidden)
            .filter(window => Settings.switcherScope === "workspace" ? window.workspace?.id === workspace
              : Settings.switcherScope === "monitor" ? window.monitor === monitor
              : true)
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
  // The key above Tab (` on a US layout, ² on a French one), by its place
  // on the keyboard rather than its character: its evdev code, 41, plus 8.
  readonly property int keyAboveTab: 49

  onKeyPressed: event => {
    // The shortcut's key reaching the panel (Hyprland takes the shortcut
    // itself, but not with Shift added): back with Shift, on otherwise.
    if (AppSwitcherState.key !== "" && root.qtKeys(AppSwitcherState.key).includes(event.key)) {
      AppSwitcherState.current += (event.modifiers & Qt.ShiftModifier) ? -1 : 1
      event.accepted = true
    } else if (event.nativeScanCode === root.keyAboveTab) {
      // Through the selected app's windows (with Shift, back).
      root.inner += (event.modifiers & Qt.ShiftModifier) ? -1 : 1
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
  // cycling switches to the selected window (when that's on).
  Item {
    id: keys
    focus: true

    Keys.onReleased: event => {
      if (Settings.switcherReleaseSwitch && AppSwitcherState.cycling && root.releaseKeys.includes(event.key) && !event.isAutoRepeat) {
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

      // Keeps the selected entry in view.
      onCurrentIndexChanged: if (list.currentIndex >= 0) list.positionViewAtIndex(list.currentIndex, ListView.Contain)

      model: ScriptModel {
        values: root.entries
      }

      delegate: Rectangle {
        id: entry

        required property var modelData
        required property int index
        readonly property bool current: entry.index === root.selected
        // The window it stands for right now (see windowOf()).
        readonly property var window: root.windowOf(entry.index)
        readonly property string iconSource: entry.window ? root.iconOf(entry.window) : ""
        readonly property color textColor: entry.current ? Theme.backgroundColor : Theme.textColor

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

        // Before the texts in a row, above them on a card: the window's
        // picture, or its icon.
        Item {
          id: media
          x: root.horizontal ? (parent.width - width) / 2 : 12
          y: root.horizontal ? 14 : (parent.height - height) / 2
          width: root.previews ? root.mediaWidth : root.iconSize
          height: root.previews ? root.mediaHeight : root.iconSize

          // Its window, live, as large as fits with its own proportions.
          ScreencopyView {
            id: preview
            visible: root.previews && preview.hasContent
            anchors.centerIn: parent
            readonly property real scale: preview.sourceSize.width > 0
              ? Math.min(parent.width / preview.sourceSize.width, parent.height / preview.sourceSize.height) : 1
            width: preview.sourceSize.width * preview.scale
            height: preview.sourceSize.height * preview.scale
            captureSource: root.previews && entry.window ? root.toplevelOf(entry.window) : null
            live: true
          }

          // Its icon: alone, or small in a corner of the picture.
          IconImage {
            id: icon
            visible: entry.iconSource !== "" && icon.status !== Image.Error
            readonly property bool corner: preview.visible
            x: icon.corner ? parent.width - width - 4 : (parent.width - width) / 2
            y: icon.corner ? parent.height - height - 4 : (parent.height - height) / 2
            width: icon.corner ? 28 : root.iconSize
            height: width
            source: entry.iconSource
          }

          // The generic glyph, where there's no icon to show (as in the
          // bar's window title and the launcher).
          ThemedText {
            visible: !icon.visible && !preview.visible
            anchors.centerIn: parent
            text: "󰀻"
            font.pixelSize: root.iconSize * 0.8
            color: entry.textColor
          }
        }

        Column {
          x: root.horizontal ? 10 : media.x + media.width + 12
          y: root.horizontal ? media.y + media.height + 10 : (parent.height - height) / 2
          width: root.horizontal ? parent.width - 20 : parent.width - x - 12
          spacing: root.horizontal ? 0 : 1

          ThemedText {
            width: parent.width
            horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            text: entry.window ? (entry.window.title || entry.window.class) : ""
            color: entry.textColor
          }

          // Its app, workspace and windows.
          ThemedText {
            width: parent.width
            horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
            text: entry.window ? root.detailsOf(entry.modelData, entry.window) : ""
            color: entry.textColor
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
