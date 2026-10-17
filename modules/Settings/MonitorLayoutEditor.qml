import QtQuick
import qs.components
import qs.config
import qs.services

// The monitors' layout, to arrange by dragging: a rectangle for each connected
// monitor at the place and size it has on the desktop, drawn to scale. A
// monitor dragged sticks to the edges of the others, and to their middle (so
// it can sit centered beside one), when it comes close, and when dropped on a free place it is moved there by
// MonitorLayout.place(), which keeps the place across config reloads. Dropped
// over another monitor, it goes back where it was. The main monitor
// (Matugen.mainMonitor) is fixed: it can't be dragged, and the others are
// placed around it. The focused monitor is outlined in the accent color.
Item {
  id: root

  // The connected monitors, and the space the view shows: where they all are,
  // plus room around them to move one.
  readonly property var monitors: MonitorLayout.shown
  readonly property rect world: {
    if (root.monitors.length === 0) return Qt.rect(0, 0, 1920, 1080)
    const left = Math.min(...root.monitors.map(m => m.x))
    const top = Math.min(...root.monitors.map(m => m.y))
    const right = Math.max(...root.monitors.map(m => m.x + m.width))
    const bottom = Math.max(...root.monitors.map(m => m.y + m.height))
    const room = Math.max(right - left, bottom - top) * 0.25
    return Qt.rect(left - room, top - room, right - left + 2 * room, bottom - top + 2 * room)
  }
  // How many pixels of the view a desktop pixel takes.
  readonly property real zoom: Math.min(area.width / root.world.width, area.height / root.world.height)
  // How close (in view pixels) an edge must be to another to stick to it.
  readonly property real snapDistance: 14

  // The drag going on: which monitor ("" for none), and where it would go
  // on the desktop.
  property string dragName: ""
  property real dragX: 0
  property real dragY: 0

  implicitWidth: 640
  implicitHeight: hint.implicitHeight + 10 + area.height

  // Where a monitor of `size` dropped near `want` ends up: each axis sticks
  // to the closest edge or middle of the other monitors within snapDistance.
  function snapped(name, want, width, height) {
    const reach = root.snapDistance / root.zoom
    let x = want.x
    let y = want.y
    let bestX = reach
    let bestY = reach
    for (const other of root.monitors) {
      if (other.name === name) continue
      // The edges, and the middle: centered on the other monitor.
      const xs = [other.x, other.x + other.width, other.x, other.x - width, other.x + other.width - width, other.x + (other.width - width) / 2]
      const ys = [other.y, other.y + other.height, other.y, other.y - height, other.y + other.height - height, other.y + (other.height - height) / 2]
      for (const candidate of xs) {
        if (Math.abs(want.x - candidate) < bestX) { bestX = Math.abs(want.x - candidate); x = candidate }
      }
      for (const candidate of ys) {
        if (Math.abs(want.y - candidate) < bestY) { bestY = Math.abs(want.y - candidate); y = candidate }
      }
    }
    return Qt.point(Math.round(x), Math.round(y))
  }

  // Whether a monitor of the given size at (x, y) would cover another.
  function overlaps(name, x, y, width, height) {
    return root.monitors.some(other => other.name !== name
      && x < other.x + other.width && other.x < x + width && y < other.y + other.height && other.y < y + height)
  }

  ThemedText {
    id: hint
    anchors.left: parent.left
    anchors.right: parent.right
    text: I18n.tr("settings.monitors.hint")
    sizeScale: 0.85
    color: Theme.separatorColor
    wrapMode: Text.WordWrap
  }

  Rectangle {
    id: area
    anchors.top: hint.bottom
    anchors.topMargin: 10
    anchors.left: parent.left
    anchors.right: parent.right
    height: 300
    radius: Theme.radiusFor(height)
    color: Theme.pillColor
    border.color: Theme.outlineColor
    border.width: 1
    clip: true

    ThemedText {
      anchors.centerIn: parent
      visible: root.monitors.length === 0
      text: I18n.tr("settings.monitors.none")
      color: Theme.separatorColor
    }

    // The view's own coordinates: the world, centered and scaled.
    Item {
      readonly property real offsetX: (area.width - root.world.width * root.zoom) / 2
      readonly property real offsetY: (area.height - root.world.height * root.zoom) / 2

      Repeater {
        model: root.monitors

        Rectangle {
          id: tile

          required property var modelData
          readonly property bool dragged: root.dragName === tile.modelData.name
          readonly property real deskX: tile.dragged ? root.dragX : tile.modelData.x
          readonly property real deskY: tile.dragged ? root.dragY : tile.modelData.y
          readonly property bool blocked: tile.dragged && root.overlaps(tile.modelData.name, root.dragX, root.dragY, tile.modelData.width, tile.modelData.height)

          x: parent.offsetX + (tile.deskX - root.world.x) * root.zoom
          y: parent.offsetY + (tile.deskY - root.world.y) * root.zoom
          width: tile.modelData.width * root.zoom
          height: tile.modelData.height * root.zoom
          radius: Theme.radiusFor(30)
          color: tile.blocked ? Theme.warningColor : tile.dragged ? Theme.accentColor : Theme.backgroundColor
          opacity: tile.dragged ? 0.8 : 1
          border.color: tile.dragged || tile.modelData.name === MonitorLayout.focused?.name ? Theme.accentColor : Theme.outlineColor
          border.width: tile.modelData.name === MonitorLayout.focused?.name ? 3 : 2
          z: tile.dragged ? 10 : 1

          Column {
            anchors.centerIn: parent
            spacing: 2

            ThemedText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: tile.modelData.name
              sizeScale: 0.95
              color: tile.dragged ? Theme.backgroundColor : Theme.textColor
            }

            ThemedText {
              anchors.horizontalCenter: parent.horizontalCenter
              text: tile.modelData.resolution
              sizeScale: 0.75
              color: tile.dragged ? Theme.backgroundColor : Theme.separatorColor
            }
          }

          MouseArea {
            anchors.fill: parent
            enabled: tile.modelData.name !== Matugen.mainMonitor
            preventStealing: true
            cursorShape: root.dragName === "" ? Qt.OpenHandCursor : Qt.ClosedHandCursor

            property point start
            property point origin

            onPressed: mouse => {
              start = mapToItem(area, mouse.x, mouse.y)
              origin = Qt.point(tile.modelData.x, tile.modelData.y)
            }
            onPositionChanged: mouse => {
              if (!pressed) return
              const at = mapToItem(area, mouse.x, mouse.y)
              if (root.dragName === "") {
                if (Math.abs(at.x - start.x) + Math.abs(at.y - start.y) < 6) return
                root.dragName = tile.modelData.name
              }
              const spot = root.snapped(tile.modelData.name, Qt.point(origin.x + (at.x - start.x) / root.zoom, origin.y + (at.y - start.y) / root.zoom), tile.modelData.width, tile.modelData.height)
              root.dragX = spot.x
              root.dragY = spot.y
            }
            onReleased: {
              if (root.dragName === "") return
              const free = !root.overlaps(tile.modelData.name, root.dragX, root.dragY, tile.modelData.width, tile.modelData.height)
              const moved = root.dragX !== tile.modelData.x || root.dragY !== tile.modelData.y
              const place = {}
              place[tile.modelData.name] = { x: root.dragX, y: root.dragY }
              root.dragName = ""
              if (free && moved) MonitorLayout.place(place)
            }
          }
        }
      }
    }
  }
}
