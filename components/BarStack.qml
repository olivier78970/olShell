import QtQuick
import qs.config

// Lays its children out side by side, centered on the bar's middle line, on a
// bar along the top or bottom of the screen, and stacked, centered the same
// way, on a side bar (Theme.barVertical): the parts of a bar widget, the
// widgets of a pill. Children don't anchor themselves (a Grid places them).
Grid {
  id: root

  // The space between the children side by side, and stacked.
  property real gap: 4
  property real stackGap: 2

  columnSpacing: root.gap
  rowSpacing: root.stackGap
  horizontalItemAlignment: Grid.AlignHCenter
  verticalItemAlignment: Grid.AlignVCenter

  // One row, or one column; the other count follows from the children, so
  // the grid is exactly their size (a fixed count larger than needed leaves
  // an empty last cell, and a spacing, at the end). Set here rather than
  // bound, in the order that never asks for a single cell in between (which
  // Grid warns about when there are more children).
  function applyOrientation() {
    if (Theme.barVertical) {
      root.rows = -1
      root.columns = 1
    } else {
      root.columns = -1
      root.rows = 1
    }
  }

  Component.onCompleted: root.applyOrientation()

  Connections {
    target: Theme

    function onBarVerticalChanged() {
      root.applyOrientation()
    }
  }
}
