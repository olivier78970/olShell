import QtQuick
import qs.config

// Text drawn in a bar widget itself (not in its popups). On a side bar, where
// the widgets and their parts are stacked, its box is only as tall as the
// font size rather than the font's full line height, which leaves empty room
// above and below the characters: the space between stacked items is then
// the one the settings give, not that plus the room around each line. On a
// top or bottom bar it's plain ThemedText.
ThemedText {
  height: Theme.barVertical ? Math.round(font.pixelSize) : implicitHeight
  verticalAlignment: Text.AlignVCenter
}
