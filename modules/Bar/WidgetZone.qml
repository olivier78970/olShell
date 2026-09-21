import QtQuick
import qs.components
import qs.config

// A bar pill filled with the widgets of one zone, in order (`widgets` is a
// list of ids, from Settings.layout). It draws the dividers Settings.dividers
// asks for, and hides itself when no widget in it has anything to show.
Pill {
  id: root

  property var widgets: []
  // Whether any widget of the zone is open in a popup that hangs off the
  // pill (the power menu), to square off the pill's corner.
  readonly property bool popupOpen: {
    root.flags  // look again when the slots change
    for (let i = 0; i < slots.count; i++) {
      if (slots.itemAt(i)?.open) return true
    }
    return false
  }

  // For each slot: whether it is shown. Rebuilt whenever a slot changes.
  property var flags: []

  visible: root.flags.some(flag => flag.shown)

  function refresh() {
    const next = []
    for (let i = 0; i < slots.count; i++) {
      const slot = slots.itemAt(i)
      next.push({ shown: slot?.shown ?? false })
    }
    root.flags = next
  }

  // Whether a divider goes before slot `index`: its widget is shown, has one
  // asked for, and something shown comes before it (a divider at the start of
  // a pill would border nothing).
  function dividerBefore(index) {
    if (!root.flags[index]?.shown || !Settings.dividers.includes(root.widgets[index])) return false
    return root.flags.slice(0, index).some(flag => flag.shown)
  }

  Repeater {
    id: slots
    model: root.widgets

    WidgetSlot {
      required property string modelData
      required property int index

      widget: modelData
      divider: root.dividerBefore(index)

      onShownChanged: Qt.callLater(root.refresh)
      onItemChanged: Qt.callLater(root.refresh)
    }

    onItemAdded: Qt.callLater(root.refresh)
    onItemRemoved: Qt.callLater(root.refresh)
  }
}
