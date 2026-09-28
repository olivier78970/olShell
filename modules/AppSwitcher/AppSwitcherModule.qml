import Quickshell
import Quickshell.Io
import qs.config

// The app switcher (AppSwitcherPanel.qml), built only while it is open and
// freed once it closes. Its `switcher` IPC target lives here, so it answers
// while the panel isn't built.
Scope {
  IpcHandler {
    target: "switcher"

    // Opens it on the previously focused window, or closes it.
    function toggle(): void {
      AppSwitcherState.toggle()
    }

    // Selects the next window (the previously focused one when it opens), for
    // a Super+Tab binding; releasing the modifier held switches to it.
    function next(): void {
      AppSwitcherState.step(1)
    }

    // Selects the window before, for a Super+Shift+Tab binding.
    function prev(): void {
      AppSwitcherState.step(-1)
    }

    // Switches to the selected window, for a binding on the modifier's
    // release (the panel may not have the keyboard yet to see it).
    function confirm(): void {
      AppSwitcherState.confirm()
    }
  }

  LazyLoader {
    active: AppSwitcherState.visible

    AppSwitcherPanel {}
  }
}
