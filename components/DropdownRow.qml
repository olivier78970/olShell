import QtQuick
import qs.config

// A label with the current value on the right; clicking it opens a list of
// the options below, from which one is picked. `options` is an array of
// { value, text }; `chosen` fires with the value picked.
//
// The owner keeps the state that keyboard handling needs: `open` (whether the
// list is showing) and `highlighted` (the entry the keys are on), and follows
// `toggled` (the row was clicked) and `highlightRequested` (the pointer moved
// over an entry). With `overlay` off (the default), the list is part of the
// row: while it's open the row's implicitHeight grows to hold it (items
// outside their parent's bounds get no mouse events), so the owner should
// size the row from that. With `overlay` on, the list instead floats above
// the rest of the panel, in `overlayHost`, so the row's height never changes
// and nothing else moves when it opens.
Item {
  id: root

  property string label: ""
  property var options: []
  property var current: null
  property bool selected: false
  property bool open: false
  property int highlighted: 0
  // Draw each entry in the font family it names (for a list of fonts).
  property bool previewFonts: false
  // The options are positions ("top-right"...): each is drawn as a PositionIcon
  // before its text (its list shows every position, in taller entries).
  property bool positionIcon: false
  // Float the list instead of growing the row to hold it.
  property bool overlay: false
  // The item the floating list is shown in: one covering the panel, above its
  // other items (the row itself when null, which clips the list to the row).
  property Item overlayHost: null
  // False for a row that can't be adjusted right now (some other setting
  // makes it have no effect); dims the row and blocks its button, and
  // `disabledReason`, if set, explains why in a tooltip on hover.
  property bool interactive: true
  property string disabledReason: ""

  signal chosen(var value)
  signal activated()
  signal toggled()
  signal highlightRequested(int index)

  readonly property int currentIndex: root.options.findIndex(option => option.value === root.current)
  readonly property int entryHeight: root.positionIcon ? 38 : 30
  readonly property int visibleEntries: root.positionIcon ? 10 : 6
  // The label and button line, and (unless overlaid) the list below it when open.
  property real headerHeight: 54
  readonly property real listHeight: Math.min(root.options.length, root.visibleEntries) * root.entryHeight + 8
  // Wide enough for a long name at the current font size, within the row.
  readonly property real listWidth: Math.min(Math.max(button.width, Theme.fontSize() * 24), header.width - 24)
  // The widest option's text, which the current value is given, so the
  // button keeps one width whatever is picked and rows with the same options
  // line up (not for a list of fonts, each drawn in its own).
  readonly property real widestText: {
    let widest = 0
    for (let i = 0; i < optionWidths.count; i++) widest = Math.max(widest, optionWidths.itemAt(i)?.implicitWidth ?? 0)
    return widest
  }
  // Whichever of the two lists below is the one actually in use.
  readonly property Item activeList: root.overlay ? overlayLoader.item : inlineLoader.item

  // Where the settings panel's column of controls starts (-1: none). The
  // control here stays against the right edge; the row just asks to be at
  // least as wide as it would be with the control lined up in that column,
  // so the panel is as wide as a page lined up that way.
  property real controlX: -1

  implicitWidth: Math.max(12 + nameText.implicitWidth + 16, root.controlX) + button.width + 12
  implicitHeight: root.headerHeight + (!root.overlay && root.open ? root.listHeight + 4 : 0)

  // Keeps the entry the keys are on in view.
  onHighlightedChanged: if (root.open) root.activeList?.positionViewAtIndex(root.highlighted, ListView.Contain)
  onOpenChanged: if (root.open) root.activeList?.positionViewAtIndex(root.highlighted, ListView.Center)

  // The row's background, without the list.
  Rectangle {
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.headerHeight
    opacity: root.interactive ? 1 : 0.45
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  ThemedText {
    id: nameText
    anchors.left: header.left
    anchors.leftMargin: 12
    anchors.verticalCenter: header.verticalCenter
    opacity: root.interactive ? 1 : 0.45
    text: root.label
  }

  // The current value, as a button that opens the list.
  Rectangle {
    id: button
    anchors.right: header.right
    anchors.rightMargin: 12
    anchors.verticalCenter: header.verticalCenter
    width: valueRow.implicitWidth + arrow.implicitWidth + 36
    height: root.positionIcon ? 38 : 30
    opacity: root.interactive ? 1 : 0.45
    radius: Theme.radiusFor(height)
    color: mouse.containsMouse || root.open ? Theme.borderColor : "transparent"
    border.color: root.open ? Theme.accentColor : Theme.outlineColor
    border.width: 1

    Row {
      id: valueRow
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10

      PositionIcon {
        visible: root.positionIcon
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 22
        position: String(root.current)
      }

      ThemedText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(implicitWidth, root.widestText)
        text: root.currentIndex >= 0 ? root.options[root.currentIndex].text : ""
        color: Theme.accentColor
      }
    }

    // Measures every option's text, for widestText; never shown.
    Repeater {
      id: optionWidths
      model: root.previewFonts ? [] : root.options

      ThemedText {
        visible: false
        text: modelData.text
      }
    }

    ThemedText {
      id: arrow
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: root.open ? "▴" : "▾"
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      enabled: root.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        root.toggled()
      }
    }
  }

  // Hover works even while the row itself is disabled, so the tooltip
  // explaining why still shows (over the label and button line only).
  HoverHandler {
    id: hover
  }

  DisabledTooltip {
    anchorItem: header
    text: root.disabledReason
    visible: hover.hovered && !root.interactive && root.disabledReason.length > 0
  }

  // The options list itself, shared by the inline row and the floating
  // overlay below (only one of which is ever loaded for a given row).
  Component {
    id: listContent

    ListView {
      id: list
      anchors.fill: parent
      anchors.margins: 4
      clip: true
      model: root.options
      boundsBehavior: Flickable.StopAtBounds

      delegate: Rectangle {
        id: entry

        required property var modelData
        required property int index
        readonly property bool active: entry.modelData.value === root.current

        width: ListView.view.width
        height: root.entryHeight
        radius: Theme.radiusFor(height)
        color: entry.index === root.highlighted ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.22) : "transparent"

        PositionIcon {
          id: entryIcon
          visible: root.positionIcon
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 34
          height: 22
          position: String(entry.modelData.value)
        }

        ThemedText {
          anchors.left: entryIcon.visible ? entryIcon.right : parent.left
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: entry.modelData.text
          elide: Text.ElideRight
          color: entry.active ? Theme.accentColor : Theme.textColor
          font.family: root.previewFonts ? entry.modelData.value : Theme.fontFamily
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.highlightRequested(entry.index)
          onClicked: root.chosen(entry.modelData.value)
        }
      }

      // Where the visible part is, when the list is longer than its box.
      Rectangle {
        visible: list.visibleArea.heightRatio < 1
        anchors.right: parent.right
        y: list.visibleArea.yPosition * list.height
        width: 3
        height: list.visibleArea.heightRatio * list.height
        radius: 1.5
        color: Theme.textColor
        opacity: 0.4
      }
    }
  }

  // The list, inline just under the button: grows the row to hold it.
  Rectangle {
    id: inlineList
    visible: root.open && !root.overlay
    anchors.top: header.bottom
    anchors.topMargin: 0
    anchors.right: header.right
    anchors.rightMargin: 12
    width: root.listWidth
    height: root.listHeight
    radius: Theme.radiusFor(height)
    color: Theme.pillColor
    border.color: Theme.accentColor
    border.width: 1

    // Keeps clicks between the entries from reaching what's under the list.
    MouseArea {
      anchors.fill: parent
    }

    Loader {
      id: inlineLoader
      anchors.fill: parent
      active: !root.overlay
      sourceComponent: listContent
    }
  }

  // The list, floating above the rest of the panel just under the button (or
  // above it when there is no room below): never resizes the row, so nothing
  // else in the panel moves when it opens. It lives in `overlayHost` (an item
  // covering the panel, above its other items), not in a window of its own:
  // a popup window opened under a still pointer got no mouse events until the
  // pointer had left and come back.
  Rectangle {
    id: floatingList
    visible: root.overlay && root.open
    z: 1
    width: root.listWidth
    height: root.listHeight
    radius: Theme.radiusFor(height)
    color: Theme.pillColor
    border.color: Theme.accentColor
    border.width: 1

    // Moved to the host once, not bound to it: a binding moves the list back
    // into the row as the panel is torn down, which crashes the shell.
    Component.onCompleted: if (root.overlayHost) floatingList.parent = root.overlayHost

    // Puts the list under the button, right-aligned with it, or above it when
    // it would go past the bottom of the host.
    function place() {
      const host = floatingList.parent
      const below = button.mapToItem(host, button.width, button.height)
      floatingList.x = below.x - floatingList.width
      const above = button.mapToItem(host, 0, 0).y - floatingList.height
      floatingList.y = below.y + floatingList.height > host.height && above >= 0 ? above : below.y
    }

    // Follows the button while the list is open (the rows can scroll under it).
    Timer {
      interval: 16
      repeat: true
      running: floatingList.visible
      triggeredOnStart: true
      onTriggered: floatingList.place()
    }

    // Keeps clicks between the entries from reaching what's under the list.
    MouseArea {
      anchors.fill: parent
    }

    Loader {
      id: overlayLoader
      anchors.fill: parent
      active: root.overlay
      sourceComponent: listContent
    }
  }
}
