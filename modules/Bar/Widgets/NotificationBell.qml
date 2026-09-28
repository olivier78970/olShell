import QtQuick
import qs.components
import qs.config
import qs.services

// Bell that opens the notification center. A left click toggles the center, a
// right click do-not-disturb. The bell is crossed out while do-not-disturb is
// on. The number of notifications in the center is written to its right (it
// goes down when one is dismissed), or under it on a side bar.
Item {
  id: root

  // Red while an urgent notification is waiting, else accent-colored while
  // there is any.
  readonly property color tint: Notifications.urgent ? Theme.warningColor
    : (Notifications.count > 0 && !Notifications.dnd ? Theme.accentColor : Theme.textColor)

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  BarStack {
    id: content
    anchors.centerIn: parent
    gap: 6

    BarText {
      text: Notifications.dnd ? "󰂛" : "󰂚"
      color: root.tint
    }

    // The number of notifications in the center; nothing when there are none.
    BarText {
      visible: Notifications.count > 0
      text: Notifications.count
      sizeScale: Theme.barFigureScale
      color: root.tint
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) Notifications.setDnd(!Notifications.dnd)
      else NotificationCenterState.toggle()
    }
  }
}
