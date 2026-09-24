pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Keeps Hyprland's compositor blur in sync with Settings.blur. Every layer
// surface the shell draws (the bar, widget pills, popups, panels, OSDs -
// everything Theme.widgetOpacity can fade) shares Quickshell's default
// "quickshell" layer-shell namespace, so one dynamic layer rule turns blur
// on or off for all of them at once, live, without a Hyprland config change.
// Hyprland's Lua config uses its "non-legacy" parser, which `hyprctl keyword`
// can't set rules on; `hyprctl eval` runs the same layer_rule() call the
// static config does instead.
//
// The namespace match is a regex, searched rather than fully matched (see
// the commented-out example in the user's own hyprland.lua), so without the
// ^...$ anchors it would also catch the "quickshell:backdrop" namespace the
// panels' click-catching backdrops use (ModalPanel, NotificationCenter,
// ClockPanel...), blurring surfaces meant to stay plainly transparent.
Singleton {
  id: root

  readonly property bool active: Settings.blur
  // Settings load a moment after this singleton's own first frame, even
  // with the settings file read synchronously (see Bar.qml's `settled` for
  // the same quirk): `active` briefly reads Settings.blur's compile-time
  // default before flipping to the saved value, all within the same
  // startup instant, and Hyprland doesn't reliably pick up a rule that
  // flips twice that quickly - toggling the setting by hand afterwards
  // would apply cleanly, but the saved-on state wouldn't stick from a
  // fresh shell start. Waiting for that flip to settle before applying for
  // the first time avoids ever sending the spurious value.
  property bool settled: false

  onActiveChanged: if (root.settled) root.apply()

  Timer {
    interval: 200
    running: true
    onTriggered: {
      root.settled = true
      root.apply()
    }
  }

  // Dynamic layer rules added with `hyprctl eval` don't survive a config
  // reload - and something (the wallpaper/matugen pipeline regenerating
  // ~/.config/hypr/colors.lua a few seconds into a fresh login) does
  // trigger a real one early on, silently dropping the rule this singleton
  // set at startup. Reapplying whenever Hyprland reports one keeps it in
  // sync regardless of what caused it.
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name === "configreloaded" && root.settled) root.apply()
    }
  }

  function apply() {
    process.command = ["hyprctl", "eval", `hl.layer_rule({ match = { namespace = "^quickshell$" }, blur = ${root.active} })`]
    process.running = true
  }

  Process {
    id: process
  }
}
