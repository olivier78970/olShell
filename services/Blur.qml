pragma Singleton

import QtQuick
import Quickshell
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

  onActiveChanged: root.apply()
  Component.onCompleted: root.apply()

  function apply() {
    process.command = ["hyprctl", "eval", `hl.layer_rule({ match = { namespace = "^quickshell$" }, blur = ${root.active} })`]
    process.running = true
  }

  Process {
    id: process
  }
}
