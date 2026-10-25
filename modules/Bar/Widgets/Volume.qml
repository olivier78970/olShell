import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Output volume percentage (on a side bar, a ring filled to it around the
// icon, the figure in a popup on hover); scroll over it to adjust, click to
// run its action (Settings.volumeAction, pavucontrol by default),
// middle-click to mute or unmute, right-click for a menu muting or unmuting
// or opening pavucontrol.
Item {
  id: root

  // Whether it shows as a ring around its icon (its figures in the popup): with
  // the vertical layout (Settings.volumeLayout), and with the automatic one on a
  // side bar.
  readonly property bool ring: Settings.volumeLayout === "vertical" || (Settings.volumeLayout === "auto" && Theme.barVertical)

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
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onEntered: popup.hoverEntered()
    onExited: popup.hoverExited()
    // Left: runs its action (see services/WidgetActions.qml). Middle: mutes
    // or unmutes (the OSD shows it). Right: the menu.
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        popup.dismiss()
        menu.open = !menu.open
      } else if (mouse.button === Qt.MiddleButton) Audio.toggleMute()
      else {
        menu.open = false
        WidgetActions.run("volume")
      }
    }
    onWheel: wheel => Audio.adjust((wheel.angleDelta.y / 120) * root.step)
  }

  // Opens pavucontrol, or closes it when it's running.
  function mixer() {
    Quickshell.execDetached(["sh", "-c", "pkill -x pavucontrol || exec pavucontrol"])
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    PopupTitle {
      text: I18n.tr("settings.widget.volume")
      inMenu: true
    }

    // Mutes or unmutes (the OSD shows it, as for the other ways).
    PowerMenuOption {
      icon: Audio.muted ? "󰕾" : "󰝟"
      label: I18n.tr(Audio.muted ? "volume.unmute" : "volume.mute")
      onClicked: {
        menu.open = false
        Audio.toggleMute()
      }
    }

    PowerMenuOption {
      icon: "󰕾"
      label: I18n.tr("volume.mixer")
      onClicked: {
        menu.open = false
        root.mixer()
      }
    }
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
