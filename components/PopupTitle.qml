import QtQuick
import qs.config

// The title at the top of a bar widget's popup or menu, naming the widget it
// comes from, in the accent color. In a menu (`inMenu`), it lines up with the
// entries' labels (see PowerMenuOption).
ThemedText {
  property bool inMenu: false

  color: Theme.accentColor
  leftPadding: inMenu ? 12 : 0
  rightPadding: inMenu ? 12 : 0
  topPadding: inMenu ? 4 : 0
  bottomPadding: inMenu ? 4 : 0
}
