import QtQuick
import qs.components
import qs.config

// The bar's layout, to arrange by dragging: a lane for each zone of the bar
// (left, center, right) holding its groups in bar order, each group one
// cell with its widgets in it, a lane of the widgets that are off, and a lane
// of the ones that are disabled (off the bar and not loaded at all).
//
// A widget dragged into a group joins it where it is dropped; dropped in a
// lane but outside any group, it starts a group of its own there; dropped on
// the off lane, it is turned off, and on the disabled lane, disabled. A group
// dragged by its handle (on its left) moves with its widgets and mode to where
// it is dropped in a lane, or turns them all off (or disables them) on the
// off (or disabled) lane. A line shows where the drop would go.
// Each group's button switches its mode: shown, shown on hover, hidden. The
// changes go to Settings.arrange(), which refuses to turn off the settings
// button.
Item {
  id: root

  // What the lanes show: Settings.arrangement(), and the widgets off.
  readonly property var zones: Settings.arrangement()
  readonly property var offWidgets: Settings.widgetIds.filter(id => Settings.zoneOf(id) === "off" && Settings.widgetEnabled(id))
  readonly property var disabledWidgets: Settings.widgetIds.filter(id => !Settings.widgetEnabled(id))

  // The icon of each widget, as the bar draws it.
  readonly property var icons: ({
    launcher: "", settings: "󰒓", workspaces: "󰕰", activeWindow: "󰖯", clock: "󰥔",
    wallpaper: "󰋩", theme: "󰏘", screenshot: "󰄀", zoom: "󱡴", shortcuts: "󰌌",
    tray: "󰀻", cpu: "󰻠", ram: "󰍛", disk: "󰋊", network: "󰛳", connection: "󰖩",
    bluetooth: "󰂯", volume: "󰕾", notifications: "󰂚", lock: "󰌾", power: "󰐥", chatAi: "󰭹", webApps: "󰖟"
  })
  // The icon of each group mode, in the order the button goes through them.
  readonly property var modeIcons: ({ on: "󰈈", hover: "󰍽", off: "󰈉" })

  // The drag going on: what is dragged ("widget", "group" or "" for none),
  // which (a widget's id, or the zone and place of a group), where the
  // pointer is (in this item), and where a drop there would go (see
  // targetAt()).
  property string dragKind: ""
  property string dragWidget: ""
  property string dragZone: ""
  property int dragGroup: -1
  property point pointer: Qt.point(0, 0)
  property var target: null

  implicitWidth: 640
  implicitHeight: content.implicitHeight

  // Starts dragging a widget, or the group `group` of `zone`.
  function beginWidgetDrag(id, zone) {
    root.dragKind = "widget"
    root.dragWidget = id
    root.dragZone = zone
  }

  function beginGroupDrag(zone, group) {
    root.dragKind = "group"
    root.dragZone = zone
    root.dragGroup = group
  }

  // Follows the pointer, at `point` in this item.
  function dragTo(point) {
    root.pointer = point
    root.target = root.targetAt(point)
  }

  // Drops what is dragged where the pointer is, and ends the drag.
  function endDrag() {
    const target = root.target
    const kind = root.dragKind
    root.dragKind = ""
    root.target = null
    if (target === null) return
    if (kind === "widget") root.dropWidget(root.dragWidget, root.dragZone, target)
    else if (kind === "group") root.dropGroup(root.dragZone, root.dragGroup, target)
  }

  // The rectangle of `item` in this item's coordinates.
  function rectOf(item) {
    const corner = item.mapToItem(root, 0, 0)
    return Qt.rect(corner.x, corner.y, item.width, item.height)
  }

  function contains(item, point) {
    const rect = root.rectOf(item)
    return point.x >= rect.x && point.x <= rect.x + rect.width && point.y >= rect.y && point.y <= rect.y + rect.height
  }

  // Where among `items` (laid out in rows, left to right) a drop at `point`
  // goes: the index of the item it would come before.
  function insertionIn(items, point) {
    for (let index = 0; index < items.length; index++) {
      const rect = root.rectOf(items[index])
      if (point.y < rect.y) return index
      if (point.y <= rect.y + rect.height && point.x < rect.x + rect.width / 2) return index
    }
    return items.length
  }

  // Where a drop at `point` goes: { zone: "off" }, { zone, group, index } (in
  // group `group` of the zone, before its widget `index`; widgets only), or
  // { zone, newGroup } (a group of its own before group `newGroup`); null
  // outside the lanes.
  function targetAt(point) {
    if (root.contains(offLane, point)) return { zone: "off" }
    if (root.contains(disabledLane, point)) return { zone: "disabled" }
    for (let lane = 0; lane < lanes.count; lane++) {
      const item = lanes.itemAt(lane)
      if (!item || !root.contains(item, point)) continue
      const cells = item.cells()
      if (root.dragKind === "widget") {
        for (let group = 0; group < cells.length; group++) {
          if (root.contains(cells[group], point))
            return { zone: item.zone, group: group, index: root.insertionIn(cells[group].chips(), point) }
        }
      }
      return { zone: item.zone, newGroup: root.insertionIn(cells, point) }
    }
    return null
  }

  // A copy of the zones' groups that can be changed.
  function copyZones() {
    const zones = {}
    for (const zone of Settings.zones)
      zones[zone] = root.zones[zone].map(group => ({ ids: group.ids.slice(), mode: group.mode }))
    return zones
  }

  // Takes the empty places (null) and the groups left empty out of `zones`.
  function cleaned(zones) {
    for (const zone of Settings.zones)
      zones[zone] = zones[zone].filter(group => group !== null).map(group => ({ ids: group.ids.filter(id => id !== null), mode: group.mode })).filter(group => group.ids.length > 0)
    return zones
  }

  // Whether a zone name is one of the lanes off the bar.
  function away(zone) {
    return zone === "off" || zone === "disabled"
  }

  // Moves widget `id` (in `from`, a zone, "off" or "disabled") to `target`. It is first
  // blanked where it was, so the target's places still count as they were.
  function dropWidget(id, from, target) {
    if (root.away(target.zone) && id === "settings") return
    const zones = root.copyZones()
    if (!root.away(from)) {
      for (const group of zones[from]) {
        const index = group.ids.indexOf(id)
        if (index >= 0) group.ids[index] = null
      }
    }
    if (!root.away(target.zone)) {
      if (target.group !== undefined) zones[target.zone][target.group].ids.splice(target.index, 0, id)
      else zones[target.zone].splice(target.newGroup, 0, { ids: [id], mode: "on" })
    }
    const cleaned = root.cleaned(zones)
    cleaned.disabled = Settings.disabledWidgets.filter(other => other !== id).concat(target.zone === "disabled" ? [id] : [])
    Settings.arrange(cleaned)
  }

  // Moves group `group` of zone `from`, with its mode, to `target` (before
  // group `newGroup` of its zone, or off).
  function dropGroup(from, group, target) {
    const zones = root.copyZones()
    const moved = zones[from][group]
    if (root.away(target.zone) && moved.ids.includes("settings")) return
    zones[from][group] = null
    if (!root.away(target.zone)) zones[target.zone].splice(target.newGroup, 0, moved)
    const cleaned = root.cleaned(zones)
    cleaned.disabled = Settings.disabledWidgets.filter(other => !moved.ids.includes(other)).concat(target.zone === "disabled" ? moved.ids : [])
    Settings.arrange(cleaned)
  }

  // Switches group `group` of `zone` to its next mode.
  function nextMode(zone, group) {
    const leader = root.zones[zone][group].ids[0]
    const modes = Settings.groupModes
    Settings.setGroupMode(leader, modes[(modes.indexOf(Settings.groupMode(leader)) + 1) % modes.length])
  }

  Column {
    id: content
    width: parent.width
    spacing: 12

    Repeater {
      id: lanes
      model: Settings.zones

      Lane {
        id: zoneLane
        required property string modelData

        zone: modelData
        // The left and right zones are the top and bottom ones of a side bar.
        title: I18n.tr("settings.zone." + modelData + (Theme.barVertical && modelData !== "center" ? ".side" : ""))

        // The group cells of the lane, in order.
        function cells() {
          const items = []
          for (let index = 0; index < groupRepeater.count; index++) items.push(groupRepeater.itemAt(index))
          return items
        }

        Repeater {
          id: groupRepeater
          model: root.zones[zoneLane.zone] ?? []

          GroupCell {
            required property var modelData
            required property int index

            zone: zoneLane.zone
            maxWidth: zoneLane.flowItem.width
            groupIndex: index
            ids: modelData.ids
            mode: modelData.mode
          }
        }
      }
    }

    // The widgets that are off.
    Lane {
      id: offLane
      zone: "off"
      title: I18n.tr("settings.zone.off")

      Repeater {
        model: root.offWidgets

        Chip {
          required property string modelData
          widget: modelData
          zone: "off"
        }
      }
    }

    // The widgets that are disabled: unloaded, with their feature.
    Lane {
      id: disabledLane
      zone: "disabled"
      title: I18n.tr("settings.zone.disabled")

      Repeater {
        model: root.disabledWidgets

        Chip {
          required property string modelData
          widget: modelData
          zone: "disabled"
        }
      }
    }
  }

  // Where a drop would go: a line before the place, or after the last.
  Rectangle {
    id: indicator

    readonly property var place: root.indicatorPlace()

    visible: root.dragKind !== "" && place !== null
    x: place ? place.x - width / 2 : 0
    y: place ? place.y : 0
    width: 3
    height: place ? place.height : 0
    radius: 1.5
    color: Theme.accentColor
    z: 10
  }

  // The line's place for the current target: { x, y, height }, or null when
  // there's none to draw (the off lane lights up instead).
  function indicatorPlace() {
    const target = root.target
    if (target === null || root.away(target.zone)) return null
    const lane = lanes.itemAt(Settings.zones.indexOf(target.zone))
    if (!lane) return null
    const items = target.group !== undefined ? lane.cells()[target.group].chips() : lane.cells()
    const index = target.group !== undefined ? target.index : target.newGroup
    const container = target.group !== undefined ? lane.cells()[target.group] : lane.flowItem
    if (items.length === 0) {
      const rect = root.rectOf(container)
      return { x: rect.x + 8, y: rect.y + 6, height: Math.max(20, rect.height - 12) }
    }
    const rect = root.rectOf(items[Math.min(index, items.length - 1)])
    const gap = target.group !== undefined ? 3 : 5
    return { x: index < items.length ? rect.x - gap : rect.x + rect.width + gap, y: rect.y, height: rect.height }
  }

  // What is dragged, under the pointer.
  Rectangle {
    visible: root.dragKind !== ""
    x: root.pointer.x + 12
    y: root.pointer.y + 12
    width: ghostText.implicitWidth + 20
    height: 30
    radius: Theme.radiusFor(height)
    color: Theme.pillColor
    border.color: Theme.accentColor
    border.width: 1
    opacity: 0.9
    z: 20

    ThemedText {
      id: ghostText
      anchors.centerIn: parent
      text: root.dragKind === "widget" ? root.icons[root.dragWidget] + "  " + I18n.tr("settings.widget." + root.dragWidget)
        : root.dragKind === "group" ? I18n.tr("settings.layout.groupOf", root.zones[root.dragZone]?.[root.dragGroup]?.ids.length ?? 0) : ""
      sizeScale: 0.85
    }
  }

  // A zone's lane: its name, then what's in it, wrapping.
  component Lane: Rectangle {
    id: lane

    property string zone: ""
    property string title: ""
    readonly property Item flowItem: flow
    default property alias items: flow.data
    // Lit while a drop there would turn something off.
    readonly property bool lit: root.away(lane.zone) && root.target?.zone === lane.zone

    width: parent.width
    height: laneTitle.height + flow.height + 20
    radius: Theme.radiusFor(40)
    color: lane.lit ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: lane.lit ? Theme.accentColor : Theme.outlineColor
    border.width: 1

    ThemedText {
      id: laneTitle
      anchors.top: parent.top
      anchors.topMargin: 6
      anchors.left: parent.left
      anchors.leftMargin: 12
      text: lane.title
      opacity: 0.7
      sizeScale: 0.8
    }

    Flow {
      id: flow
      anchors.top: laneTitle.bottom
      anchors.topMargin: 6
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 10
      spacing: 10
      // Room to drop into an empty lane.
      height: Math.max(implicitHeight, 36)
    }
  }

  // A group: its handle, its mode button and its widgets, wrapping onto more
  // lines when they don't fit in `maxWidth` (its lane's).
  component GroupCell: Rectangle {
    id: cell

    property string zone: ""
    property real maxWidth: 600
    property int groupIndex: 0
    property var ids: []
    property string mode: "on"
    readonly property bool dragged: root.dragKind === "group" && root.dragZone === cell.zone && root.dragGroup === cell.groupIndex

    // Its widgets' chips, in order.
    function chips() {
      const items = []
      for (let index = 0; index < chipRepeater.count; index++) items.push(chipRepeater.itemAt(index))
      return items
    }

    // How wide its chips are together, on one line (again when they change,
    // or the font size does).
    readonly property real chipsWidth: {
      void Theme.fontSize()
      let total = 0
      for (let index = 0; index < chipRepeater.count; index++) total += (chipRepeater.itemAt(index)?.width ?? 0) + cellRow.spacing
      return total
    }

    // As wide as everything on one line, within its lane.
    width: Math.min(cell.maxWidth, Math.ceil(handle.width + modeButton.width + cell.chipsWidth + cellRow.spacing) + 13)
    height: cellRow.implicitHeight + 12
    radius: Theme.radiusFor(height)
    color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.05)
    border.color: Theme.outlineColor
    border.width: 1
    opacity: cell.dragged ? 0.35 : (cell.mode === "off" ? 0.55 : 1)

    Flow {
      id: cellRow
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      // The handle the group is dragged by.
      ThemedText {
        id: handle
        height: 30
        verticalAlignment: Text.AlignVCenter
        text: "󰇛"
        opacity: handleMouse.containsMouse ? 1 : 0.6

        MouseArea {
          id: handleMouse
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          preventStealing: true
          cursorShape: root.dragKind === "" ? Qt.OpenHandCursor : Qt.ClosedHandCursor

          property point start

          onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
          onPositionChanged: mouse => {
            if (!pressed) return
            if (root.dragKind === "" && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 6)
              root.beginGroupDrag(cell.zone, cell.groupIndex)
            if (root.dragKind !== "") root.dragTo(mapToItem(root, mouse.x, mouse.y))
          }
          onReleased: if (root.dragKind !== "") root.endDrag()
        }
      }

      // The mode button: shown, on hover, hidden.
      Rectangle {
        id: modeButton
        width: 30
        height: 30
        radius: Theme.radiusFor(height)
        color: modeMouse.containsMouse ? Theme.borderColor : "transparent"
        border.color: Theme.outlineColor
        border.width: 1

        ThemedText {
          anchors.centerIn: parent
          text: root.modeIcons[cell.mode]
          color: cell.mode === "on" ? Theme.accentColor : Theme.textColor
          sizeScale: 0.85
        }

        MouseArea {
          id: modeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.nextMode(cell.zone, cell.groupIndex)
        }
      }

      Repeater {
        id: chipRepeater
        model: cell.ids

        Chip {
          required property string modelData
          widget: modelData
          zone: cell.zone
        }
      }
    }
  }

  // A widget: its icon and name, dragged anywhere.
  component Chip: Rectangle {
    id: chip

    property string widget: ""
    property string zone: ""
    readonly property bool dragged: root.dragKind === "widget" && root.dragWidget === chip.widget

    width: chipText.implicitWidth + 20
    height: 30
    radius: Theme.radiusFor(height)
    color: chipMouse.containsMouse && root.dragKind === "" ? Theme.borderColor : Theme.pillColor
    border.color: Theme.outlineColor
    border.width: 1
    opacity: chip.dragged ? 0.35 : 1

    ThemedText {
      id: chipText
      anchors.centerIn: parent
      text: (root.icons[chip.widget] ?? "") + "  " + I18n.tr("settings.widget." + chip.widget)
      sizeScale: 0.85
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: root.dragKind === "" ? Qt.OpenHandCursor : Qt.ClosedHandCursor

      property point start

      onPressed: mouse => start = Qt.point(mouse.x, mouse.y)
      onPositionChanged: mouse => {
        if (!pressed) return
        if (root.dragKind === "" && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 6)
          root.beginWidgetDrag(chip.widget, chip.zone)
        if (root.dragKind !== "") root.dragTo(mapToItem(root, mouse.x, mouse.y))
      }
      onReleased: if (root.dragKind !== "") root.endDrag()
    }
  }
}
