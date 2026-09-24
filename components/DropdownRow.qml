import QtQuick
import Quickshell
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
// the rest of the panel in its own window, so the row's height never changes
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

  signal chosen(var value)
  signal activated()
  signal toggled()
  signal highlightRequested(int index)
  // The overlay popup is a separate window, and Wayland gives a newly shown
  // one keyboard focus (unlike the inline list, still part of the panel's own
  // window): keys landing there are forwarded here instead of being handled
  // locally, so the owner's existing key handling for the list (the same one
  // driving the inline case) covers it too.
  signal overlayKeyPressed(var event)

  readonly property int currentIndex: root.options.findIndex(option => option.value === root.current)
  readonly property int entryHeight: root.positionIcon ? 38 : 30
  readonly property int visibleEntries: root.positionIcon ? 8 : 6
  // The label and button line, and (unless overlaid) the list below it when open.
  property real headerHeight: 54
  readonly property real listHeight: Math.min(root.options.length, root.visibleEntries) * root.entryHeight + 8
  // Wide enough for a long name at the current font size, within the row.
  readonly property real listWidth: Math.min(Math.max(button.width, Theme.fontSize() * 24), header.width - 24)
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
  onOpenChanged: {
    // The overlay is a real popup window, not part of the row, so it needs
    // telling explicitly (a plain binding would fight the popup's own grab
    // dismissing it, see overlayPopup.onVisibleChanged below).
    if (root.overlay) overlayPopup.visible = root.open
    if (root.open) root.activeList?.positionViewAtIndex(root.highlighted, ListView.Center)
  }

  // The row's background, without the list.
  Rectangle {
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.headerHeight
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
        text: root.currentIndex >= 0 ? root.options[root.currentIndex].text : ""
        color: Theme.accentColor
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
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        root.toggled()
      }
    }
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

  // The list, floating in its own window below the button: never resizes
  // the row, so nothing else in the panel moves when it opens.
  PopupWindow {
    id: overlayPopup
    visible: false
    anchor.item: button
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.bottom: 0
    // Matches every other popup in the shell (the bar's menus, tooltips):
    // grabbing focus is what makes a click outside it dismiss it.
    grabFocus: true
    implicitWidth: root.listWidth
    implicitHeight: root.listHeight
    color: "transparent"

    // The compositor can dismiss this itself (a click outside it, since it
    // grabs focus); tell the owner so root.openKey and this row's arrow
    // don't get stuck thinking it's still open.
    onVisibleChanged: {
      if (!overlayPopup.visible && root.open) root.toggled()
      // Being shown is what actually gives this window keyboard focus.
      if (overlayPopup.visible) overlayContent.forceActiveFocus()
    }

    Rectangle {
      id: overlayContent
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      color: Theme.pillColor
      border.color: Theme.accentColor
      border.width: 1
      focus: true

      // Arrow keys, Enter, Escape... land here, not on the panel behind it:
      // forward them to the owner, which already knows how to handle them
      // (the same code the inline list's keys go through).
      Keys.onPressed: event => root.overlayKeyPressed(event)

      Loader {
        id: overlayLoader
        anchors.fill: parent
        active: root.overlay
        sourceComponent: listContent
      }
    }
  }
}
