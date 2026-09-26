import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.modules.Osd
import qs.services

// The lock screen: a session lock (the compositor shows nothing but these
// surfaces, one per screen, until it is unlocked) with the time and a password
// field, checked by PAM (see services/Lock.qml). It is started from the bar's
// lock button, `ipc call lock lock`, or by the idle timer below.
Scope {
  id: root

  // Locks after Settings.lockTimeout minutes without input (0: never). Playing
  // video and the like, which inhibit idling, hold it off.
  IdleMonitor {
    enabled: Settings.lockTimeout > 0 && !Lock.locked
    timeout: Settings.lockTimeout * 60
    respectInhibitors: true
    onIsIdleChanged: if (isIdle) Lock.lock()
  }

  WlSessionLock {
    locked: Lock.locked

    WlSessionLockSurface {
      id: surface

      color: Theme.backgroundColor

      property date now: new Date()

      Timer {
        interval: 1000
        running: Lock.locked
        repeat: true
        triggeredOnStart: true
        onTriggered: surface.now = new Date()
      }

      // The wallpaper, blurred and darkened a little so the text reads on it
      // (the theme background shows until it is loaded, or if there is none).
      Image {
        id: wallpaper
        anchors.fill: parent
        visible: false
        source: ThemeState.wallpaper.length > 0 ? "file://" + ThemeState.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(surface.width, surface.height)
        asynchronous: true
      }

      MultiEffect {
        anchors.fill: parent
        visible: wallpaper.status === Image.Ready
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.15
      }

      // Anywhere on the screen brings the keyboard back to the field.
      MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
      }

      Column {
        anchors.centerIn: parent
        spacing: 12

        ThemedText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: surface.now.toLocaleString(I18n.locale, I18n.value("lock.timeFormat"))
          sizeScale: 5
          color: Theme.textColor
        }

        ThemedText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: surface.now.toLocaleString(I18n.locale, I18n.value("lock.dateFormat"))
          sizeScale: 1.3
          color: Theme.textColor
          opacity: 0.7
        }

        Item {
          width: 1
          height: 24
        }

        // The password field: dots for what has been typed.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 340
          height: Theme.fontSize() + 26
          radius: Theme.radiusFor(height)
          color: Theme.pillColor
          border.color: Lock.error.length > 0 ? Theme.warningColor : Theme.accentColor
          border.width: 2
          opacity: Lock.checking ? 0.6 : 1

          ThemedText {
            anchors.centerIn: parent
            visible: Lock.password.length === 0
            text: Lock.checking ? I18n.tr("lock.checking") : I18n.tr("lock.prompt")
            opacity: 0.5
          }

          TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Password
            passwordCharacter: "•"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize()
            color: Theme.textColor
            enabled: !Lock.checking
            focus: true
            text: Lock.password

            onTextEdited: Lock.password = input.text
            onAccepted: Lock.submit()
            Component.onCompleted: input.forceActiveFocus()
            // Back on the field after a failed try (it is disabled while PAM works).
            onEnabledChanged: if (input.enabled) input.forceActiveFocus()
          }
        }

        ThemedText {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: Lock.error.length > 0
          text: Lock.error
          color: Theme.warningColor
        }
      }

      // The volume keys still work while locked (their Hyprland binds are
      // `locked`), but the volume OSD can't show over the session lock:
      // the same pill shows here instead, for a moment after each change.
      VolumePill {
        x: Theme.osdOffset(Theme.volumeOsdPosition, Theme.volumeOsdMargin, parent.width, width, false)
        y: Theme.osdOffset(Theme.volumeOsdPosition, Theme.volumeOsdMargin, parent.height, height, true)
        visible: volumeTimer.running
      }

      Timer {
        id: volumeTimer
        interval: 1500
      }

      Connections {
        target: Audio

        function onVolumeChanged() {
          volumeTimer.restart()
        }

        function onMutedChanged() {
          volumeTimer.restart()
        }
      }
    }
  }
}
