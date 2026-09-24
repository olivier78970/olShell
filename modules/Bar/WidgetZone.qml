import QtQuick
import qs.components
import qs.config

// A bar pill filled with the widgets of one zone, in order (`widgets` is a
// list of ids, from Settings.layout). It draws the dividers Settings.dividers
// asks for, and hides itself when no widget in it has anything to show.
// A group (the widgets between two dividers) can be set to show only while the
// pointer is over the pill ("hover": it slides open, and shut again shortly
// after the pointer leaves) or never ("off"), see Settings.groupMode. A pill
// with nothing left showing keeps a small dots handle to hover.
Pill {
  id: root

  property var widgets: []
  // Whether any widget of the zone is open in a popup that hangs off the
  // pill, which keeps an auto-hiding bar out.
  readonly property bool popupOpen: {
    root.flags  // look again when the slots change
    for (let i = 0; i < slots.count; i++) {
      if (slots.itemAt(i)?.open) return true
    }
    return false
  }

  // Whether the pointer is in the pill, or was a moment ago, so the groups are
  // not shut the instant it strays. (The group of a widget with a popup open
  // also stays, whatever the pointer does, or the popup would lose its anchor;
  // the other groups shut as usual.)
  property bool expanded: false

  onHoveredChanged: {
    if (root.hovered) {
      shutTimer.stop()
      root.expanded = true
    } else {
      shutTimer.restart()
    }
  }

  Timer {
    id: shutTimer
    interval: 500
    onTriggered: root.expanded = false
  }

  // For each slot: whether it is shown. Rebuilt whenever a slot changes.
  property var flags: []

  // Something to show, now or on hover.
  readonly property bool anyPresent: root.flags.some((flag, index) => flag.shown && root.modeAt(index) !== "off")
  visible: root.anyPresent

  function refresh() {
    const next = []
    for (let i = 0; i < slots.count; i++) {
      const slot = slots.itemAt(i)
      next.push({ shown: slot?.shown ?? false })
    }
    root.flags = next
  }

  // The widget that starts the group slot `index` belongs to.
  function groupStart(index) {
    let start = root.widgets[0]
    for (let i = 1; i <= index; i++) {
      if (Settings.dividers.includes(root.widgets[i])) start = root.widgets[i]
    }
    return start
  }

  // The mode ("on", "hover" or "off") of the group slot `index` belongs to.
  function modeAt(index) {
    return Settings.groupMode(root.groupStart(index))
  }

  // Whether a widget of the group slot `index` belongs to has a popup open.
  function groupHasPopup(index) {
    root.flags  // look again when the slots change
    const start = root.groupStart(index)
    for (let i = 0; i < slots.count; i++) {
      if (slots.itemAt(i)?.open && root.groupStart(i) === start) return true
    }
    return false
  }

  // Whether the group slot `index` belongs to is hidden right now: it is off,
  // or on hover and the pointer isn't in the pill (nor a popup of the group open).
  function groupCollapsed(index) {
    const mode = root.modeAt(index)
    return mode === "off" || (mode === "hover" && !root.expanded && !root.groupHasPopup(index))
  }

  // Whether slot `index` is showing now: its widget is, and its group isn't hidden.
  function showing(index) {
    return (root.flags[index]?.shown ?? false) && !root.groupCollapsed(index)
  }

  // Whether every widget that could show is in a group hidden until hover.
  readonly property bool allHidden: root.anyPresent && !root.flags.some((flag, index) => root.showing(index))

  // Whether a divider goes before slot `index`: its widget is showing, has one
  // asked for, and something showing comes before it (a divider at the start of
  // a pill would border nothing).
  function dividerBefore(index) {
    if (!root.showing(index) || !Settings.dividers.includes(root.widgets[index])) return false
    for (let i = 0; i < index; i++) {
      if (root.showing(i)) return true
    }
    return false
  }

  // What is left of a pill whose groups are all hidden.
  ThemedText {
    visible: root.allHidden
    anchors.verticalCenter: parent.verticalCenter
    text: "󰇘"
  }

  Repeater {
    id: slots
    model: root.widgets

    WidgetSlot {
      required property string modelData
      required property int index

      widget: modelData
      divider: root.dividerBefore(index)
      collapsed: root.groupCollapsed(index)

      onShownChanged: Qt.callLater(root.refresh)
      onItemChanged: Qt.callLater(root.refresh)
    }

    onItemAdded: Qt.callLater(root.refresh)
    onItemRemoved: Qt.callLater(root.refresh)
  }
}
