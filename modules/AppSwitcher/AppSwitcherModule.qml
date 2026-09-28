import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The app switcher (AppSwitcherPanel.qml), built only while it is open and
// freed once it closes. Its `switcher` IPC target lives here, so it answers
// while the panel isn't built.
Scope {
  IpcHandler {
    target: "switcher"

    // Opens it on the previously focused window; bound to a shortcut, which
    // it finds in the Hyprland config, pressing that again moves on and
    // releasing its modifier switches (see AppSwitcherState.toggle()).
    function toggle(): void {
      AppSwitcherState.toggle()
    }

    // Selects the next window (the previously focused one when it opens);
    // releasing the modifier held switches to it.
    function next(): void {
      AppSwitcherState.step(1)
    }

    // Selects the window before (the last one when it opens).
    function prev(): void {
      AppSwitcherState.step(-1)
    }

    // Closes it without switching.
    function close(): void {
      AppSwitcherState.visible = false
    }

    // Switches to the selected window, for a binding on the modifier's
    // release (the panel may not have the keyboard yet to see it).
    function confirm(): void {
      AppSwitcherState.confirm()
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: AppSwitcherState.visible
  }

  LazyLoader {
    active: linger.active

    AppSwitcherPanel {}
  }
}
