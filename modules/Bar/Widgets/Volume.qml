import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Output volume percentage (on a side bar, a ring filled to it around the
// icon, the figure in a popup on hover); scroll over it to adjust, click to
// open or close pavucontrol, middle-click to mute or unmute.
Item {
  id: root

  // Whether it shows as a ring around its icon (its figures in the popup):
  // always on a side bar, and on a top or bottom bar too with its setting.
  readonly property bool ring: Theme.barVertical || Settings.volumeRing

  // Fraction of full volume to change per standard wheel notch (120 units
  // of angleDelta). Scaled by actual delta so touchpads/high-res mice,
  // which send many small events per gesture, change volume smoothly
  // instead of snapping by this whole step on every event.
  readonly property real step: 0.03

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: root.ring ? ring.implicitWidth : content.implicitWidth
  implicitHeight: root.ring ? ring.implicitHeight : content.implicitHeight

  BarStack {
    id: content
    visible: !root.ring
    anchors.centerIn: parent
    gap: 4

    BarText {
      text: Audio.icon
      sizeScale: 1.4
    }

    BarText {
      text: Audio.percent + "%"
    }
  }

  // On a side bar: a ring filled to the volume, faint while muted.
  BarGauge {
    id: ring
    visible: root.ring
    anchors.centerIn: parent
    value: Audio.volume
    icon: Audio.icon
    color: Audio.muted ? Theme.fade(Theme.textColor, 0.4) : Theme.accentColor
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
    // Left: closes pavucontrol if it's running, opens it otherwise. Middle:
    // mutes or unmutes (the OSD shows it, as for the other ways).
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) Audio.toggleMute()
      else Quickshell.execDetached(["sh", "-c", "pkill -x pavucontrol || exec pavucontrol"])
    }
    onWheel: wheel => Audio.adjust((wheel.angleDelta.y / 120) * root.step)
  }

  // The volume, on a side bar, where only the ring shows it.
  HoverPopup {
    id: popup
    anchorItem: root
    showWhen: root.ring

    PopupTitle {
      text: I18n.tr("settings.widget.volume")
    }

    ThemedText {
      text: Audio.muted ? I18n.tr("volume.muted", Audio.percent) : Audio.percent + "%"
    }
  }
}
