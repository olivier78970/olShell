import QtQuick
import qs.config

// Text styled with the shell's font and text color. `sizeScale` multiplies
// the standard bar font size (e.g. 1.4 for icons); `color` can still be
// overridden for states like hover.
Text {
  property real sizeScale: 1

  color: Theme.textColor
  font.family: Theme.fontFamily
  font.weight: Theme.fontWeight
  font.letterSpacing: Theme.fontLetterSpacing
  font.capitalization: Theme.fontCapitalization
  font.italic: Theme.fontItalic
  font.underline: Theme.fontUnderline
  font.pixelSize: Theme.fontSize() * sizeScale
  // The outline, when on, is in the accent color: the background color would
  // vanish into the pills, which are nearly the same.
  style: Theme.fontOutline ? Text.Outline : Text.Normal
  styleColor: Theme.accentColor
}
