import QtQuick
import qs.components
import qs.config

// One place in a bar pill: a widget from BarWidgets, with the divider that
// goes before it when `divider` is set (WidgetZone works that out). The slot
// is hidden, divider included, while the widget has nothing to show.
Row {
  id: root

  // The widget's id (a key of BarWidgets.components).
  property string widget: ""
  property bool divider: false

  // The loaded widget, and whether it has something to show (a widget can
  // say it hasn't with a `present` property, as the window title does when
  // there is no window).
  readonly property Item item: loader.item
  readonly property bool shown: root.item !== null && (root.item.present ?? true)
  // Whether the widget has a popup menu open (the power menu says so).
  readonly property bool open: root.item?.menuOpen ?? false

  // The pill's row centers its widgets vertically by their own anchors.
  anchors.verticalCenter: parent.verticalCenter
  visible: root.shown
  spacing: Theme.widgetSpacing

  Separator {
    visible: root.divider
  }

  Loader {
    id: loader
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: BarWidgets.components[root.widget]
  }
}
