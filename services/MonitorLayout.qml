pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Where the monitors sit on the desktop, and how the focused one is set. It
// lists the connected monitors with their size on the desktop and place (read
// with `hyprctl monitors all`), and sets each one's position, mode, scale,
// mirroring, color depth and HDR with `hyprctl eval` (the Lua config's parser
// refuses `hyprctl keyword`, like in services/Blur.qml). The places
// chosen in the settings (Settings.monitorPositions) are kept, and put back
// after a config reload, which restores the config's own, and when a monitor
// is plugged in.
Singleton {
  id: root

  // The connected monitors: { name, description, x, y, width, height } with
  // the size the monitor takes on the desktop (its resolution over its scale,
  // swapped when it is rotated a quarter turn), its resolution in pixels
  // (pixelWidth, pixelHeight, and `resolution` as text), its current `mode`
  // ("2560x1440@299.99", as Hyprland lists them without the "Hz") and the
  // `modes` it offers, its `scale`, `transform`, `mirror` (the name of the
  // monitor it shows, "" for none), `bitdepth` and `hdr`.
  property var monitors: []
  // Every monitor Hyprland lists, turned off or not: { name, description,
  // disabled }. A turned-off monitor is left out of `monitors`, so this is
  // what lets the settings offer to turn it back on.
  property var known: []
  // The monitors that take a place of their own on the desktop: those not
  // mirroring another (which Hyprland draws over it and leaves out of the
  // layout).
  readonly property var shown: root.monitors.filter(monitor => monitor.mirror === "")
  // The focused monitor (null when none), whose settings the panel offers.
  readonly property var focused: root.monitors.find(monitor => monitor.name === Hyprland.focusedMonitor?.name) ?? null

  // A mode "2560x1440@299.99" as "2560×1440 @ 299.99 Hz", the rate as
  // Hyprland lists it.
  function modeText(mode) {
    const [size, rate] = mode.split("@")
    return size.replace("x", "×") + " @ " + rate + " Hz"
  }

  // The modes of the focused monitor as the settings' dropdown lists them.
  readonly property var focusedModeOptions: (root.focused?.modes ?? []).map(mode => ({ value: mode, text: root.modeText(mode) }))

  // Moves the monitors to `changes`, { name: { x, y } and/or { mode, scale, ... } },
  // the fields missing staying as they are, and keeps them in
  // Settings.monitorPositions.
  function place(changes) {
    const saved = Object.assign({}, Settings.monitorPositions)
    for (const name of Object.keys(changes)) saved[name] = Object.assign({}, saved[name], changes[name])
    Settings.set("monitorPositions", saved)
  }

  // Where a monitor goes along one axis when the monitor `target` (at
  // `targetStart`, `targetSize` long) becomes `newSize` long and keeps its
  // start: the monitor at `start`, `size` long, stays against the same side.
  // Past the target's far edge it moves by the change in size; before its
  // start it stays; alongside it (overlapping its range) it keeps the
  // alignment it had - start, end or middle - or else its distance from the
  // start.
  function follow(start, size, targetStart, targetSize, newSize) {
    if (start >= targetStart + targetSize) return start + newSize - targetSize
    if (start + size <= targetStart) return start
    if (Math.abs(start - targetStart) <= 1) return targetStart
    if (Math.abs(start + size - targetStart - targetSize) <= 1) return targetStart + newSize - size
    if (Math.abs(start + size / 2 - targetStart - targetSize / 2) <= 1) return Math.round(targetStart + (newSize - size) / 2)
    return start
  }

  // The names of the monitors that are turned off in the settings and can
  // be: at least one monitor always stays on, the first of those asked off
  // (in Hyprland's order).
  readonly property var turnedOff: {
    const asked = root.known.filter(monitor => Settings.disabledMonitors.includes(monitor.name)).map(monitor => monitor.name)
    return asked.length < root.known.length ? asked : asked.slice(1)
  }

  // True while a monitor is being turned off or on, and for a moment after:
  // Hyprland then moves its workspaces to another monitor, which the bar
  // must not take for the user switching workspace (it would close the
  // open panel).
  property bool changing: false

  Timer {
    id: changingTimer
    interval: 2000
    onTriggered: root.changing = false
  }

  // Turns the monitor `name` off or on. Turning off the last one on does
  // nothing. A monitor turned off first has its place, mode and scale saved
  // (those not already), so it comes back as it was.
  function setEnabled(name, on) {
    const others = Settings.disabledMonitors.filter(other => other !== name)
    root.hold()
    if (!on && !root.known.some(monitor => monitor.name !== name && !others.includes(monitor.name))) return
    const current = root.monitors.find(monitor => monitor.name === name)
    if (!on && current) {
      const saved = Settings.monitorPositions[name] ?? {}
      const keep = {}
      for (const field of ["x", "y", "mode", "scale"]) if (saved[field] === undefined) keep[field] = current[field]
      if (Object.keys(keep).length > 0) root.place({ [name]: keep })
    }
    Settings.set("disabledMonitors", on ? others : others.concat([name]))
  }

  // Sets the focused monitor's mode. Its size on the desktop changes with it
  // (see resize()).
  function setMode(mode) {
    const target = root.focused
    if (target === null || mode === target.mode) return
    root.resize({ mode: mode }, mode, target.scale)
  }

  // The scales offered for the focused monitor: those giving a whole size on
  // the desktop, and the current one if it isn't among them.
  readonly property var focusedScaleOptions: {
    const scales = []
    const target = root.focused
    for (let hundredths = 50; hundredths <= 300 && target !== null; hundredths += 5) {
      const scale = hundredths / 100
      const whole = pixels => Math.abs(pixels / scale - Math.round(pixels / scale)) < 0.001
      if (whole(target.pixelWidth) && whole(target.pixelHeight)) scales.push(scale)
    }
    const current = target?.scale
    if (current !== undefined && !scales.includes(current)) scales.push(current)
    return scales.sort((a, b) => a - b).map(scale => ({ value: scale, text: Math.round(scale * 100) + " %" }))
  }

  // Sets the focused monitor's scale. Its size on the desktop changes with
  // it (see resize()).
  function setScale(scale) {
    const target = root.focused
    if (target === null || scale === target.scale) return
    root.resize({ scale: scale }, target.mode, scale)
  }

  // Applies `fields` ({ mode } or { scale }) to the focused monitor, which
  // then takes the size `mode` over `scale` gives on the desktop. The other
  // monitors are moved to keep their place around it (see follow()). The
  // main monitor (Matugen.mainMonitor) stays where it is, everything else
  // being shifted instead.
  function resize(fields, mode, scale) {
    const target = root.focused
    const [pixels] = mode.split("@")
    const [pixelWidth, pixelHeight] = pixels.split("x").map(Number)
    const turned = target.transform % 2 === 1
    const width = Math.round((turned ? pixelHeight : pixelWidth) / scale)
    const height = Math.round((turned ? pixelWidth : pixelHeight) / scale)
    const moves = {}
    for (const monitor of root.shown) {
      moves[monitor.name] = monitor.name === target.name ? { x: target.x, y: target.y } : {
        x: root.follow(monitor.x, monitor.width, target.x, target.width, width),
        y: root.follow(monitor.y, monitor.height, target.y, target.height, height)
      }
    }
    const main = root.shown.find(monitor => monitor.name === Matugen.mainMonitor)
    const shiftX = main ? moves[main.name].x - main.x : 0
    const shiftY = main ? moves[main.name].y - main.y : 0
    const changes = {}
    for (const monitor of root.shown) {
      const x = moves[monitor.name].x - shiftX
      const y = moves[monitor.name].y - shiftY
      if (x !== monitor.x || y !== monitor.y || monitor.name === target.name) changes[monitor.name] = { x: x, y: y }
    }
    Object.assign(changes[target.name], fields)
    root.place(changes)
  }

  // The names of the monitors showing the focused one, which has no
  // mirroring of its own then: its dropdown says so, and Off stops them.
  readonly property var mirroredBy: root.monitors.filter(monitor => monitor.mirror === root.focused?.name).map(monitor => monitor.name)
  // What the mirroring dropdown shows as current: what the monitor shows ("" is
  // none), or "by" when others show it.
  readonly property string focusedMirror: root.focused?.mirror ? root.focused.mirror : root.mirroredBy.length > 0 ? "by" : ""
  readonly property var focusedMirrorOptions: [{ value: "", text: I18n.tr("settings.monitors.mirrorOff") }]
    .concat(root.focusedMirror === "by" ? [{ value: "by", text: I18n.tr("settings.monitors.mirroredBy", root.mirroredBy.join(", ")) }] : [])
    .concat(root.shown.filter(monitor => monitor.name !== root.focused?.name)
      .map(monitor => ({ value: monitor.name, text: I18n.tr("settings.monitors.mirrorOf", monitor.name) })))

  // What each monitor declares it can do, { name: { bits, hdr } } (see
  // scripts/monitor-caps.py).
  property var capabilities: ({})
  // The settings that only some monitors can do list nothing for the others,
  // and their rows are left out of the panel (see `available` in the rows):
  // 10-bit for a monitor declaring it (or already using it), HDR for one
  // declaring HDR (or already using it), mirroring when there are two
  // monitors, and the scales giving a whole size on the desktop.
  readonly property var depthOptions: (root.capabilities[root.focused?.name]?.bits ?? 8) >= 10 || root.focused?.bitdepth === 10
    ? [{ value: 8, text: I18n.tr("settings.monitors.bits", 8) }, { value: 10, text: I18n.tr("settings.monitors.bits", 10) }] : []
  readonly property var hdrOptions: root.capabilities[root.focused?.name]?.hdr || root.focused?.hdr
    ? [{ value: false, text: I18n.tr("settings.monitors.hdrOff") }, { value: true, text: I18n.tr("settings.monitors.hdrOn") }] : []

  // Sets the focused monitor to show the monitor `name` ("" for none).
  function setMirror(name) {
    if (root.focused === null || name === "by") return
    if (name === "" && root.focused.mirror === "") {
      // Off for a monitor others show: they stop showing it.
      const changes = {}
      for (const other of root.mirroredBy) changes[other] = root.spotFor(other)
      if (Object.keys(changes).length > 0) root.place(changes)
    } else if (name === "") {
      const changes = {}
      changes[root.focused.name] = root.spotFor(root.focused.name)
      root.place(changes)
    } else if (name !== root.focused.mirror) {
      // The monitor's place is kept for when it stops mirroring (Hyprland
      // reports the other monitor's meanwhile).
      const spot = root.focused.mirror === "" ? { x: root.focused.x, y: root.focused.y } : {}
      root.setField(Object.assign({ mirror: name }, spot))
    }
  }

  // The fields that put the monitor `name` back in the layout when it stops
  // mirroring: its place from before it did, or else just right of the others
  // (it shows over the other monitor's place until then).
  function spotFor(name) {
    const saved = Settings.monitorPositions[name]
    if (saved?.x !== undefined && saved?.y !== undefined) return { mirror: "", x: saved.x, y: saved.y }
    const others = root.shown.filter(monitor => monitor.name !== name)
    return { mirror: "", x: Math.max(0, ...others.map(monitor => monitor.x + monitor.width)), y: others[0]?.y ?? 0 }
  }

  // Sets the focused monitor's color depth (8 or 10 bits) or HDR.
  function setDepth(bits) {
    if (root.focused !== null && bits !== root.focused.bitdepth) root.setField({ bitdepth: bits })
  }

  function setHdr(on) {
    if (root.focused !== null && on !== root.focused.hdr) root.setField({ hdr: on })
  }

  // Saves and applies `fields` for the focused monitor, which change nothing
  // of the layout.
  function setField(fields) {
    const change = {}
    change[root.focused.name] = fields
    root.place(change)
  }

  // The monitors whose brightness can be set, { name: { kind, target, percent } }
  // (see scripts/monitor-brightness.py), and the brightness asked of each
  // while a change is on its way.
  property var brightness: ({})

  // The most Hyprland's `sdrbrightness` (how bright ordinary content looks
  // in HDR) goes up to on the slider: 100 % is this many times its default.
  readonly property real sdrMaximum: 6

  // The focused monitor's brightness in percent (null if it can't be set).
  // With HDR on, monitors ignore their own brightness, so it is how bright
  // ordinary content looks (Hyprland's `sdrbrightness`) that is set instead.
  readonly property var focusedBrightness: root.focused?.hdr ? Math.round(100 * root.focused.sdr / root.sdrMaximum)
    : root.brightness[root.focused?.name]?.percent ?? null

  // Sets the focused monitor's brightness. Changes come quickly while a
  // slider is dragged and each takes a moment over DDC, so one is sent at a
  // time and only the latest asked for afterwards.
  function setBrightness(percent) {
    const name = root.focused?.name
    if (root.focused?.hdr) {
      root.setField({ sdr: Math.max(0.1, Math.round(percent * root.sdrMaximum) / 100) })
      return
    }
    const entry = root.brightness[name]
    if (entry === undefined || root.brightnessIgnored[name]) return
    const value = Math.max(0, Math.min(100, Math.round(percent)))
    const next = Object.assign({}, root.brightness)
    next[name] = Object.assign({}, entry, { percent: value })
    root.brightness = next
    brightnessProcess.pending[name] = value
    root.sendBrightness()
  }

  function sendBrightness() {
    if (brightnessProcess.running) return
    const name = Object.keys(brightnessProcess.pending)[0]
    if (name === undefined) return
    const value = brightnessProcess.pending[name]
    delete brightnessProcess.pending[name]
    const entry = root.brightness[name]
    brightnessProcess.sending = name
    brightnessProcess.command = ["python3", Paths.monitorBrightnessScript, "set", entry.kind, entry.target, String(value)]
    brightnessProcess.running = true
  }

  // The monitors that took a brightness command and ignored it (some do, for
  // instance with an eco or dynamic contrast mode on): their slider is
  // disabled, saying so.
  property var brightnessIgnored: ({})

  Process {
    id: brightnessProcess

    // The values still to send, by monitor name, and the monitor being sent.
    property var pending: ({})
    property string sending: ""

    onExited: (code, status) => {
      if (code === 0) return
      const ignored = Object.assign({}, root.brightnessIgnored)
      ignored[brightnessProcess.sending] = true
      root.brightnessIgnored = ignored
      // Show what the monitor really has.
      brightnessListProcess.running = true
    }
    onRunningChanged: if (!running) root.sendBrightness()
  }

  Process {
    id: brightnessListProcess
    running: true
    command: ["python3", Paths.monitorBrightnessScript, "list"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.brightness = JSON.parse(this.text)
        } catch (e) {}
      }
    }
  }

  // True while each screen shows its monitor's name (see identify()).
  property bool identifying: false

  // Shows the name of each monitor on its own screen for a few seconds, to
  // tell which is which.
  function identify() {
    root.identifying = true
    identifyTimer.restart()
  }

  Timer {
    id: identifyTimer
    interval: 4000
    onTriggered: root.identifying = false
  }

  // Sets the places, modes and options saved for the monitors that are
  // connected, if they differ from what those have. Each monitor keeps its
  // rotation. The color depth, HDR (the "hdr" color preset, else "auto") and
  // mirroring are only sent for a monitor that has them saved; Hyprland keeps
  // the fields a call leaves out.
  function apply() {
    const commands = []
    // The monitors to turn off, and those turned off to turn back on, with
    // the place and mode saved for them or else Hyprland's own choice.
    for (const name of root.turnedOff) {
      if (root.monitors.some(monitor => monitor.name === name)) commands.push(`hl.monitor({ output = "${name}", disabled = true })`)
    }
    for (const monitor of root.known) {
      if (!monitor.disabled || root.turnedOff.includes(monitor.name)) continue
      const saved = Settings.monitorPositions[monitor.name] ?? {}
      const position = saved.x !== undefined ? `${saved.x}x${saved.y}` : "auto"
      commands.push(`hl.monitor({ output = "${monitor.name}", disabled = false, mode = "${saved.mode ?? "preferred"}", position = "${position}", scale = ${saved.scale ?? '"auto"'} })`)
    }
    for (const monitor of root.monitors) {
      if (root.turnedOff.includes(monitor.name)) continue
      const saved = Settings.monitorPositions[monitor.name] ?? {}
      const wanted = Object.assign({ x: monitor.x, y: monitor.y, mode: monitor.mode, scale: monitor.scale, mirror: monitor.mirror, bitdepth: monitor.bitdepth, hdr: monitor.hdr, sdr: monitor.sdr }, saved)
      if (wanted.x === monitor.x && wanted.y === monitor.y && wanted.mode === monitor.mode && wanted.scale === monitor.scale
          && wanted.mirror === monitor.mirror && wanted.bitdepth === monitor.bitdepth && wanted.hdr === monitor.hdr && wanted.sdr === monitor.sdr) continue
      let extra = ""
      if (saved.mirror !== undefined) extra += `, mirror = "${wanted.mirror}"`
      if (saved.bitdepth !== undefined) extra += `, bitdepth = ${wanted.bitdepth}`
      if (saved.sdr !== undefined) extra += `, sdrbrightness = ${wanted.sdr}`
      if (saved.hdr !== undefined) extra += `, cm = "${wanted.hdr ? "hdr" : "auto"}"`
      commands.push(`hl.monitor({ output = "${monitor.name}", mode = "${wanted.mode}", position = "${wanted.x}x${wanted.y}", scale = ${wanted.scale}, transform = ${monitor.transform}${extra} })`)
    }
    if (commands.length === 0) return
    // A change asked for while the last is still being sent (dragging the
    // brightness slider) waits for it, and is sent after.
    if (applyProcess.running) {
      applyProcess.again = true
      return
    }
    applyProcess.command = ["hyprctl", "eval", commands.join("; ")]
    applyProcess.running = true
  }

  // Reads the monitors; `reapply` also puts the saved places back, which a
  // read after a move leaves out so a refused place doesn't loop.
  function refresh(reapply = true) {
    listProcess.reapply = reapply
    listProcess.running = true
  }

  Component.onCompleted: root.refresh()

  Process {
    id: capsProcess
    running: true
    command: ["python3", Paths.monitorCapsScript]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.capabilities = JSON.parse(this.text)
        } catch (e) {}
      }
    }
  }

  Process {
    id: listProcess

    property bool reapply: true

    command: ["hyprctl", "monitors", "all", "-j"]

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          // (Hyprland gives the monitor mirrored as its id.)
          const everything = JSON.parse(this.text)
          root.known = everything.map(monitor => ({ name: monitor.name, description: monitor.description, disabled: monitor.disabled }))
          const listed = everything.filter(monitor => !monitor.disabled)
          const names = {}
          for (const monitor of listed) names[String(monitor.id)] = monitor.name
          root.monitors = listed.map(monitor => {
            const turned = monitor.transform % 2 === 1
            const scale = Math.round(monitor.scale * 100) / 100
            const width = monitor.width / scale
            const height = monitor.height / scale
            return {
              name: monitor.name,
              description: monitor.description,
              x: monitor.x,
              y: monitor.y,
              width: Math.round(turned ? height : width),
              height: Math.round(turned ? width : height),
              pixelWidth: monitor.width,
              pixelHeight: monitor.height,
              resolution: monitor.width + "×" + monitor.height,
              mode: monitor.width + "x" + monitor.height + "@" + monitor.refreshRate.toFixed(2),
              modes: monitor.availableModes.map(mode => mode.replace("Hz", "")).filter((mode, index, all) => all.indexOf(mode) === index),
              scale: scale,
              mirror: names[monitor.mirrorOf] ?? (monitor.mirrorOf === "none" ? "" : monitor.mirrorOf),
              bitdepth: /101010|16161616/.test(monitor.currentFormat) ? 10 : 8,
              sdr: Math.round(monitor.sdrBrightness * 100) / 100,
              hdr: monitor.colorManagementPreset === "hdr" || monitor.colorManagementPreset === "hdredid",
              transform: monitor.transform
            }
          })
          if (listProcess.reapply) root.apply()
        } catch (e) {}
      }
    }
  }

  // After a move, read the places back.
  Process {
    id: applyProcess

    // Whether something was asked for while it ran.
    property bool again: false

    onRunningChanged: {
      if (running) return
      if (applyProcess.again) {
        applyProcess.again = false
        root.apply()
      } else {
        root.refresh(false)
      }
    }
  }

  // Whatever changes the saved places - a move, applying a profile, a page's
  // Reset - puts the monitors there.
  Connections {
    target: Settings

    function onMonitorPositionsChanged() {
      root.apply()
    }

    // A tick later, once turnedOff has followed the setting (it is read by
    // apply() and may not be updated yet when this signal is handled).
    function onDisabledMonitorsChanged() {
      Qt.callLater(root.apply)
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name.startsWith("monitor")) root.hold()
      if (event.name === "configreloaded" || event.name.startsWith("monitor")) root.reload()
    }
  }

  // Marks a monitor change under way (see `changing`), for a monitor
  // plugged or unplugged: its workspaces move to another monitor, which must
  // not close the open panel either.
  function hold() {
    root.changing = true
    changingTimer.restart()
  }

  // Reads everything about the monitors again.
  function reload() {
    root.refresh()
    capsProcess.running = true
    brightnessListProcess.running = true
  }

  // Hyprland sends no monitor event when a monitor turned off is unplugged
  // or plugged back, so it would stay missing from the list. The kernel's
  // hotplug events (a cable plugged or unplugged) are watched too, and the
  // monitors are read once they settle and Hyprland has handled them.
  Process {
    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=drm"]

    stdout: SplitParser {
      onRead: line => {
        if (!line.includes("(drm)")) return
        root.hold()
        hotplugTimer.restart()
      }
    }
  }

  Timer {
    id: hotplugTimer
    interval: 1500
    onTriggered: root.reload()
  }
}
