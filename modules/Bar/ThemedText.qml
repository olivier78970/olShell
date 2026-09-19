import QtQuick
import qs.config

// Text styled with the shell's font and text color. `sizeScale` multiplies
// the standard bar font size (e.g. 1.4 for icons); `color` can still be
// overridden for states like hover.
Text {
  property real sizeScale: 1

  color: Theme.textColor
  font.family: Theme.fontFamily
  font.pixelSize: Theme.fontSize() * sizeScale
}
