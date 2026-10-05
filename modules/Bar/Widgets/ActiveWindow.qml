import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config

// Icon and title of the currently focused window (any compositor
// supporting wlr-foreign-toplevel-management, not just Hyprland). A window
// whose icon can't be found gets a generic application glyph instead. On a
// side bar (or with the vertical layout, Settings.activeWindowLayout) only the
// icon shows, and hovering it shows the title. On a bar along the top or
// bottom the title is shortened (with an ellipsis) so its pill doesn't run
// into the next one: the bar tells the pill how much room it has
// (WidgetZone's maxWidth).
Row {
  id: root

  // Whether only the icon shows (the title on hover): with the vertical layout,
  // and with the automatic one on a side bar.
  readonly property bool iconOnly: Settings.activeWindowLayout === "vertical" || (Settings.activeWindowLayout === "auto" && Theme.barVertical)

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property var desktopEntry: root.toplevel ? DesktopEntries.byId(root.toplevel.appId) : null
  readonly property int maxTitleWidth: 700
  // The pill this widget is in, which knows how much room there is.
  readonly property Item zone: {
    let item = root.parent
    while (item && !item.isWidgetZone) item = item.parent
    return item
  }
  // How wide the title may be to keep the pill within its room (a very large
  // number for no limit). Set by fit() below rather than bound, since the
  // pill's width depends on the title's.
  property real titleRoom: 1e6

  // Shortens the title by how far the pill overruns its room, or lets it grow
  // back by what is left of it; the width changes this causes call it again
  // until the pill fits.
  function fit() {
    if (!root.zone || root.iconOnly) {
      root.titleRoom = 1e6
      return
    }
    const over = root.zone.width - root.zone.maxWidth
    if (over > 0.5) root.titleRoom = Math.max(0, Math.floor(titleText.width - over))
    else if (over < -0.5 && titleText.width < titleText.implicitWidth) root.titleRoom = Math.floor(titleText.width - over)
  }

  Connections {
    target: root.zone

    function onWidthChanged() { root.fit() }
    function onMaxWidthChanged() { root.fit() }
  }

  onIconOnlyChanged: root.fit()
  Component.onCompleted: root.fit()
  // The window's icon: its desktop entry's (a theme icon, or a file for an
  // absolute path), or else one named after its app id; "" when the icon
  // theme has neither.
  readonly property string iconSource: {
    const icon = root.desktopEntry ? root.desktopEntry.icon : ""
    if (icon.startsWith("/")) return "file://" + icon
    if (icon !== "") return Quickshell.iconPath(icon, true)
    return root.toplevel ? Quickshell.iconPath(root.toplevel.appId, true) : ""
  }

  anchors.verticalCenter: parent.verticalCenter
  spacing: 8
  // Whether there is a window to show; the bar's slot hides the widget (and the
  // divider before it) when there isn't.
  readonly property bool present: root.toplevel !== null
  visible: root.present

  Item {
    anchors.verticalCenter: parent.verticalCenter
    width: Theme.trayIconSize()
    height: Math.max(icon.height, glyph.height)

    IconImage {
      id: icon
      visible: root.iconSource !== "" && icon.status !== Image.Error
      anchors.centerIn: parent
      width: Theme.trayIconSize()
      height: Theme.trayIconSize()
      source: root.iconSource
    }

    // The generic glyph, where there's no icon to show (the launcher uses the
    // same for an application without one).
    BarText {
      id: glyph
      visible: !icon.visible
      anchors.centerIn: parent
      width: Theme.trayIconSize()
      horizontalAlignment: Text.AlignHCenter
      text: "󰀻"
    }

    // On a side bar, where the title doesn't show, hovering the icon shows it.
    MouseArea {
      anchors.fill: parent
      enabled: root.iconOnly
      hoverEnabled: true
      onEntered: tooltip.hoverEntered()
      onExited: tooltip.hoverExited()
    }
  }

  BarText {
    id: titleText
    visible: !root.iconOnly
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, root.maxTitleWidth, root.titleRoom)
    // A new title may be longer or shorter than the last: start from its own
    // width again.
    onImplicitWidthChanged: {
      root.titleRoom = 1e6
      root.fit()
    }
    text: root.toplevel ? root.toplevel.title : ""
    elide: Text.ElideRight

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: titleText.truncated ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: tooltip.hoverEntered()
      onExited: tooltip.hoverExited()
    }
  }

  HoverPopup {
    id: tooltip
    anchorItem: root
    alignLeft: true
    marginLeft: -Theme.pillPadding
    // Only worth showing when the title is actually cut off, or not shown.
    showWhen: titleText.truncated || root.iconOnly

    PopupTitle {
      text: I18n.tr("settings.widget.activeWindow")
    }

    ThemedText {
      text: titleText.text
    }
  }
}
