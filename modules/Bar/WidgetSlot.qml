import QtQuick
import qs.components
import qs.config

// One place in a bar pill: a widget from BarWidgets, with the divider that
// goes before it when `divider` is set (WidgetZone works that out). The slot
// is hidden, divider included, while the widget has nothing to show, and
// slides shut (and fades) while `collapsed`, when its group is hidden until
// its pill is hovered.
Row {
  id: root

  // The widget's id (a key of BarWidgets.components).
  property string widget: ""
  property bool divider: false
  property bool collapsed: false
  // How open the slot is, from 0 (shut) to 1, following `collapsed`.
  property real reveal: root.collapsed ? 0 : 1

  // The loaded widget, and whether it has something to show (a widget can
  // say it hasn't with a `present` property, as the window title does when
  // there is no window).
  readonly property Item item: loader.item
  readonly property bool shown: root.item !== null && (root.item.present ?? true)
  // Whether the widget has a popup menu open (the clock says so).
  readonly property bool open: root.item?.menuOpen ?? false

  // The pill's row centers its widgets vertically by their own anchors.
  anchors.verticalCenter: parent.verticalCenter
  visible: root.shown && root.reveal > 0
  clip: root.reveal < 1
  opacity: root.reveal
  width: Math.round(implicitWidth * root.reveal)
  spacing: Theme.widgetSpacing

  Behavior on reveal {
    NumberAnimation {
      duration: 150
      easing.type: Easing.OutCubic
    }
  }

  Separator {
    visible: root.divider
  }

  Loader {
    id: loader
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: BarWidgets.components[root.widget]
  }
}
