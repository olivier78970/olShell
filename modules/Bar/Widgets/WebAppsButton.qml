import QtQuick
import qs.components
import qs.config
import qs.services

// Web icon opening the launcher on its web apps tab, and on a right click a
// menu of the web apps (see services/WebApps.qml), each with its site's icon
// once found and a dot while its window is open: a click on one switches to
// its window when it is open, else opens it (with Settings.webAppCommand).
// They are added in the settings' web apps category.
Item {
  id: root

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.height

  BarText {
    id: icon
    anchors.centerIn: parent
    text: "󰖟"
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else {
        menu.open = false
        LauncherState.toggleTab("webApps")
      }
    }
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    PopupTitle {
      text: I18n.tr("settings.widget.webApps")
      inMenu: true
    }

    // Said instead of the list while there is no web app to open.
    PowerMenuOption {
      visible: WebApps.shown.length === 0
      enabled: false
      label: I18n.tr("webApps.none")
    }

    Repeater {
      model: WebApps.shown

      PowerMenuOption {
        required property var modelData
        icon: "󰖟"
        iconSource: WebApps.iconOf(modelData)
        label: modelData.name
        marked: WebApps.isOpen(modelData)
        onClicked: {
          menu.open = false
          WebApps.launch(modelData)
        }
      }
    }
  }
}
