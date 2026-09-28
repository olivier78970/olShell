pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Sets Hyprland's window look from the shell's settings: the windows' border
// width and corner radius (their own, or the shell's border width and widget
// radius; the corners are always circular, like the shell's), the gaps between windows (their own, or the shell's gap between
// elements) and around them, and the opacity of the focused window and of the
// others, overridden for the apps given their own (Settings.appOpacities).
// They are set live with `hl.config()`, and a window rule per such app with
// `hl.window_rule()`, replacing the Hyprland config's values, and set again
// after every config reload (which puts the config's back, and drops the
// rules).
//
// It also gives Hyprland's gaps_out, which the bar needs (see Bar.qml's
// exclusiveZone).
Singleton {
  id: root

  // The values sent to Hyprland.
  readonly property int borderSize: Settings.windowBorderSame ? Settings.borderWidth : Settings.windowBorderWidth
  // Following the widget radius, the outer edge of a window's border matches a
  // widget's: a widget's border is drawn inside its radius, while Hyprland
  // draws a window's outside its rounding, whose outer corner is then
  // rounding + border_size.
  readonly property int rounding: Settings.windowRoundingSame ? Math.max(0, Settings.radius - root.borderSize) : Settings.windowRounding
  readonly property int gapsIn: Settings.windowGapsInSame ? Settings.panelGap : Settings.windowGapsIn
  // The focused and the other windows' opacity: each its own, or the shell's.
  readonly property real activeOpacity: Settings.windowActiveOpacitySame ? Settings.opacity : Settings.windowActiveOpacity
  readonly property real inactiveOpacity: Settings.windowInactiveOpacitySame ? Settings.opacity : Settings.windowInactiveOpacity

  // Hyprland's gaps_out as top, right, bottom, left.
  readonly property var gapsOut: [Settings.windowGapsOut, Settings.windowGapsOut, Settings.windowGapsOut, Settings.windowGapsOut]

  // As the Lua table hl.config() takes. A rounding_power of 2 makes circular
  // corners, as Qt draws the shell's.
  readonly property string options: `{ general = { border_size = ${root.borderSize}, gaps_in = ${root.gapsIn}, gaps_out = ${Settings.windowGapsOut} }, decoration = { rounding = ${root.rounding}, rounding_power = 2, active_opacity = ${root.activeOpacity}, inactive_opacity = ${root.inactiveOpacity} } }`

  // Settings load a moment after this singleton starts (see services/Blur.qml
  // for the same wait): nothing is sent before they have settled.
  property bool settled: false

  Timer {
    interval: 200
    running: true
    onTriggered: {
      root.settled = true
      root.apply()
    }
  }

  // A slider changes them at every step of a drag: they are sent once it
  // pauses for a moment.
  onOptionsChanged: if (root.settled) applyTimer.restart()

  Connections {
    target: Settings

    function onAppOpacitiesChanged() {
      if (root.settled) applyTimer.restart()
    }
  }

  // Apps following the general opacities follow their changes too.
  Connections {
    target: root

    function onActiveOpacityChanged() {
      if (root.settled && Settings.appOpacities.some(app => app.activeSame)) applyTimer.restart()
    }

    function onInactiveOpacityChanged() {
      if (root.settled && Settings.appOpacities.some(app => app.inactiveSame)) applyTimer.restart()
    }
  }

  // The classes of the apps given a rule so far, so the rule of one taken out
  // of the list can be switched off.
  property var ruledClasses: []

  // `text` as a Lua string.
  function lua(text) {
    return '"' + text.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
  }

  // A rule for the windows of class `appClass`, named after it (declaring it
  // again under that name replaces it, windows already open included), with
  // `effect` (Lua fields).
  function appRule(appClass, effect) {
    const pattern = "^" + appClass.replace(/[.*+?^${}()|[\]\\\-]/g, "\\$&") + "$"
    return `hl.window_rule({ name = ${root.lua("olshell-opacity-" + appClass)}, match = { class = ${root.lua(pattern)} }, ${effect} })`
  }

  // The rules to send: one per app with its opacities (each its own, or the
  // general one it follows), overriding the general ones, and those of the
  // apps taken out of the list since, switched off.
  function appRules() {
    const apps = Settings.appOpacities
    const gone = root.ruledClasses.filter(appClass => !apps.some(app => app.class === appClass))
    root.ruledClasses = apps.map(app => app.class)
    return apps.map(app => root.appRule(app.class, `opacity = "${app.activeSame ? root.activeOpacity : app.active} override ${app.inactiveSame ? root.inactiveOpacity : app.inactive} override"`))
      .concat(gone.map(appClass => root.appRule(appClass, "enabled = false, opacity = \"1\"")))
      .join("\n")
  }

  Timer {
    id: applyTimer
    interval: 100
    onTriggered: root.apply()
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name !== "configreloaded" || !root.settled) return
      root.apply()
    }
  }

  function apply() {
    process.command = ["hyprctl", "eval", `hl.config(${root.options})`]
    process.running = true
    const rules = root.appRules()
    if (rules.length === 0) return
    rulesProcess.command = ["hyprctl", "eval", rules]
    rulesProcess.running = true
  }

  Process {
    id: process
  }

  Process {
    id: rulesProcess
  }
}
