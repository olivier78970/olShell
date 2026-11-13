import QtQuick
import qs.components
import qs.config
import qs.services

// hyprwhspr's dictation: a microphone, in the warning color while it records,
// an hourglass while it transcribes, a sleeping sign while its model is
// unloaded, crossed out and dimmed while the service is stopped (see
// services/Hyprwhspr.qml). A left click starts or stops a recording (or
// brings hyprwhspr up when it's stopped or unloaded); a right click opens a
// menu with a switch in its title starting or stopping the service (stopping
// it frees the model), what it's doing, the recording buttons and restarting.
Item {
  id: root

  // The color of the icon: the warning color while recording or failed.
  readonly property color tint: Hyprwhspr.state === "recording" || Hyprwhspr.state === "failed" ? Theme.warningColor : Theme.textColor

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.height

  BarText {
    id: icon
    anchors.centerIn: parent
    text: {
      switch (Hyprwhspr.state) {
      case "recording": return "󰑊"
      case "processing": return "󰔟"
      case "unloaded": return "󰒲"
      case "failed": return "󰍮"
      case "ready": return "󰍬"
      case "starting": return "󰍬"
      default: return "󰍭"
      }
    }
    color: root.tint
    sizeScale: 1.3
    opacity: Hyprwhspr.state === "ready" || Hyprwhspr.state === "recording" || Hyprwhspr.state === "processing" || Hyprwhspr.state === "failed" ? 1 : 0.5
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else {
        menu.open = false
        Hyprwhspr.record()
      }
    }
  }

  // Runs a menu entry's action and closes the menu.
  function run(action) {
    menu.open = false
    action()
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    // The title, with the switch starting or stopping the service.
    MenuSwitchHeading {
      title: true
      text: I18n.tr("settings.widget.hyprwhspr")
      checked: Hyprwhspr.on
      switchEnabled: Hyprwhspr.state !== "missing" && Hyprwhspr.state !== "starting" && Hyprwhspr.state !== "stopping"
      onToggled: {
        if (Hyprwhspr.on) Hyprwhspr.turnOff()
        else Hyprwhspr.turnOn()
      }
    }

    // What it's doing, under the title.
    PowerMenuOption {
      enabled: false
      label: I18n.tr("hyprwhspr.state." + Hyprwhspr.state)
    }

    MenuSeparator {}

    PowerMenuOption {
      enabled: Hyprwhspr.on
      label: I18n.tr(Hyprwhspr.recording ? "hyprwhspr.stopRecording" : "hyprwhspr.startRecording")
      onClicked: root.run(Hyprwhspr.record)
    }

    PowerMenuOption {
      visible: Hyprwhspr.recording
      label: I18n.tr("hyprwhspr.cancelRecording")
      onClicked: root.run(Hyprwhspr.cancel)
    }

    MenuSeparator {}

    PowerMenuOption {
      enabled: Hyprwhspr.state !== "missing"
      label: I18n.tr("hyprwhspr.restart")
      onClicked: root.run(Hyprwhspr.restart)
    }
  }
}
