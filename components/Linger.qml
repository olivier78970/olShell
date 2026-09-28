import QtQuick
import qs.config

// Stays `active` while `when` is true and for the length of an animation
// after it turns false (Theme.animationDuration): what keeps a panel built
// only while open (see the *Module.qml files) around long enough to animate
// away as it closes.
Timer {
  id: root

  property bool when: false
  readonly property bool active: root.when || root.running

  interval: Theme.animationDuration
  onWhenChanged: {
    if (root.when) root.stop()
    else root.restart()
  }
}
