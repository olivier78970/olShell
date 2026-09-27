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
//
// The widget popups and menus (PopupMenu) aren't layer surfaces but
// xdg-popups of the bar's, which `blur` alone doesn't reach: `blur_popups`
// extends it to them. And since a popup's blur covers its whole rectangle,
// `ignore_alpha` leaves out the (fully transparent) pixels past its rounded
// corners, which would otherwise show as blurred square corners. Kept low
// so it never cuts into a surface's own fill, however far
// Theme.widgetOpacity fades it.
//
// Hyprland's own blur (decoration.blur) follows the setting too, with
// `hl.config()`: turned off, it is disabled for the windows as well; while
// it's on, it is enabled and its options (radius, passes, noise, contrast,
// brightness, vibrancy, x-ray) are set from the settings. They are global -
// transparent windows get them too - and replace the Hyprland config's
// values until it reloads, when they are set again.
// X-ray (blurring only the wallpaper behind, not the windows) is also part
// of the layer rule: Hyprland's global option only reaches floating windows,
// a layer surface has its own.
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

  // X-ray is part of the layer rule too (see above).
  readonly property bool xray: Settings.blurXray
  onXrayChanged: if (root.settled) root.apply()

  // Hyprland's blur options, as the Lua table hl.config() takes: only
  // disabled while the blur is off.
  readonly property string options: !root.active ? `{ decoration = { blur = { enabled = false } } }`
    : `{ decoration = { blur = { enabled = true, size = ${Settings.blurSize}, passes = ${Settings.blurPasses}, noise = ${Settings.blurNoise}, contrast = ${Settings.blurContrast}, brightness = ${Settings.blurBrightness}, vibrancy = ${Settings.blurVibrancy}, xray = ${Settings.blurXray} } } }`

  // A slider changes them at every step of a drag: they are set once it
  // pauses for a moment. Turning the blur on or off changes them too, and
  // sends them again once they have (onActiveChanged may run first, with
  // the ones from before).
  onOptionsChanged: if (root.settled) optionsTimer.restart()

  Timer {
    id: optionsTimer
    interval: 100
    onTriggered: root.applyOptions()
  }

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
    process.command = ["hyprctl", "eval", `hl.layer_rule({ match = { namespace = "^quickshell$" }, blur = ${root.active}, blur_popups = ${root.active}, ignore_alpha = 0.1, xray = ${root.active && root.xray} })`]
    process.running = true
    root.applyOptions()
  }

  // Sets Hyprland's blur, on with its options or off.
  function applyOptions() {
    optionsProcess.command = ["hyprctl", "eval", `hl.config(${root.options})`]
    optionsProcess.running = true
  }

  Process {
    id: process
  }

  Process {
    id: optionsProcess
  }
}
