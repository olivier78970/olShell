pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.config

// The shell as the session's polkit authentication agent: when an
// application asks for administrator rights (pkexec, a settings or package
// manager window...), polkit sends the request here and
// modules/Polkit/PolkitDialog.qml asks for the password. Only one agent can
// be registered per session, so another one (polkit-gnome, say) must not be
// running; `registered` tells whether this one got in.
Singleton {
  id: root

  // Whether polkit accepted the shell as the session's agent.
  readonly property bool registered: agent.isRegistered
  // The request being answered, or null: its message, icon, the identities
  // that can authenticate, the prompt and the result.
  readonly property var flow: agent.isActive ? agent.flow : null
  // Whether a password was sent and polkit has not answered yet.
  property bool checking: false
  // Why the last try failed, until the next one.
  property string error: ""

  // Sends what was typed in answer to the current prompt.
  function submit(response) {
    if (!root.flow || !root.flow.isResponseRequired) return
    root.checking = true
    root.error = ""
    root.flow.submit(response)
  }

  function cancel() {
    if (root.flow) root.flow.cancelAuthenticationRequest()
  }

  // Picks who authenticates, when several users (the administrators) can.
  function selectIdentity(identity) {
    if (root.flow) root.flow.selectedIdentity = identity
  }

  PolkitAgent {
    id: agent

    onAuthenticationRequestStarted: {
      root.checking = false
      root.error = ""
    }
  }

  Connections {
    target: root.flow

    // polkit asks again after a wrong password (or right away, for the
    // first prompt).
    function onIsResponseRequiredChanged() {
      if (root.flow.isResponseRequired) root.checking = false
    }

    function onAuthenticationFailed() {
      root.checking = false
      root.error = I18n.tr("polkit.wrong")
    }
  }
}
