import QtQuick
import qs.components
import qs.config
import qs.services

// Camera icon: a left click takes a screenshot in the mode last chosen, a
// right click opens a menu to choose a mode (the whole screen, a rectangle
// or a window). Choosing one remembers it and takes the screenshot at once.
// The last row switches the annotation step (satty) on or off.
Item {
  id: root

  readonly property bool menuOpen: menu.visible

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.implicitHeight

  ThemedText {
    id: icon
    anchors.centerIn: parent
    text: "󰄀"
    // Dimmed while a picture is being taken.
    opacity: Screenshot.busy ? 0.5 : 1
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        menu.visible = !menu.visible
      } else {
        menu.visible = false
        Screenshot.take("")
      }
    }
  }

  // Gives the menu time to disappear before the picture is taken, so a
  // screen capture doesn't include it.
  Timer {
    id: captureTimer
    interval: 250
    onTriggered: Screenshot.take("")
  }

  PopupMenu {
    id: menu

    anchorItem: root
    alignCenter: true

    Repeater {
      model: ["screen", "region", "window"]

      PowerMenuOption {
        required property string modelData

        label: I18n.tr("screenshot." + modelData)
        active: Screenshot.mode === modelData
        onClicked: {
          Screenshot.setMode(modelData)
          menu.visible = false
          captureTimer.restart()
        }
      }
    }

    // Whether the picture is opened in satty afterwards, as a checkbox; it
    // only switches it.
    PowerMenuOption {
      icon: Screenshot.edit ? "\uf046" : "\uf096"
      label: I18n.tr("screenshot.edit")
      active: Screenshot.edit
      onClicked: {
        Screenshot.setEdit(!Screenshot.edit)
        menu.visible = false
      }
    }
  }
}
