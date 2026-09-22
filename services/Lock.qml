pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config

// The screen lock: whether the session is locked, the password being typed and
// the PAM check of it. The lock surfaces (modules/Lock/LockScreen.qml) show it;
// the bar's lock button, the idle timer (Settings.lockTimeout) and the `lock`
// IPC target start it.
Singleton {
  id: root

  property bool locked: false
  // What has been typed, shared by the surfaces of all the screens.
  property string password: ""
  // Whether the password is being checked, and what PAM last said about it
  // ("" when there is nothing to say).
  readonly property bool checking: pam.active
  property string error: ""

  function lock() {
    if (root.locked) return
    // The other panels grab the keyboard: put them away.
    WallpaperPanelState.visible = false
    ThemePanelState.visible = false
    LauncherState.visible = false
    SettingsPanelState.visible = false
    NotificationCenterState.visible = false
    PowerPanelState.visible = false
    PowerMenuState.cancel()
    root.password = ""
    root.error = ""
    root.locked = true
  }

  // Checks the typed password against the user's PAM login.
  function submit() {
    if (!root.locked || pam.active || root.password.length === 0) return
    root.error = ""
    pam.active = true
  }

  PamContext {
    id: pam

    // The stack `login` uses: the password of the user running the shell.
    config: "login"

    onPamMessage: {
      if (pam.responseRequired) pam.respond(root.password)
    }

    onCompleted: result => {
      if (result === PamResult.Success) {
        root.locked = false
        root.password = ""
        root.error = ""
      } else {
        root.error = I18n.tr("lock.wrong")
        root.password = ""
      }
    }

    onError: {
      root.error = I18n.tr("lock.failed")
      root.password = ""
    }
  }

  IpcHandler {
    target: "lock"

    // Locks the screen (there is no unlock call: that takes the password).
    function lock(): void {
      root.lock()
    }

    // 1 while the screen is locked, else 0.
    function status(): int {
      return root.locked ? 1 : 0
    }
  }
}
