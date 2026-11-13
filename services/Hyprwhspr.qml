pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// hyprwhspr, the speech-to-text daemon (its hyprwhspr.service user unit), for
// the hyprwhspr widget: whether it runs, records, transcribes or has its
// model unloaded, and the calls starting and stopping a recording, the
// service and the model. A helper script (scripts/hyprwhspr-watch.py) prints
// its state whenever it changes; it only runs while the widget is enabled.
// IPC (target `hyprwhspr`): `status` gives the state, `record` starts or
// stops a recording, `cancel` drops the one going on, `on` / `off` start or
// stop the service (stopping it frees the model), `unload` / `reload` free
// the model or load it back without stopping the service, `restart` restarts
// the service.
Singleton {
  id: root

  // Whether the daemon is watched: while the hyprwhspr widget is enabled.
  readonly property bool watching: Settings.widgetEnabled("hyprwhspr")
  // The state the helper script last printed. Like Printers.queue, it's only
  // ever replaced by a new line.
  property var current: ({ service: "inactive", recording: false, processing: false, unloaded: false })

  // systemd's state of the unit (active, activating, deactivating, inactive,
  // failed), or "missing" when hyprwhspr isn't installed.
  readonly property string service: root.watching ? root.current.service : "inactive"
  readonly property bool running: root.service === "active"
  readonly property bool recording: root.watching && root.current.recording
  // Transcribing what was just recorded (only known with hyprwhspr's mic-osd
  // overlay on).
  readonly property bool processing: root.watching && root.current.processing
  // The model was unloaded to free the GPU; the service still runs.
  readonly property bool unloaded: root.watching && root.current.unloaded
  // Running with its model loaded, so a recording can start: what the
  // widget's on/off switch shows.
  readonly property bool on: root.running && !root.unloaded
  // One word for the state: missing, failed, starting, stopping, stopped,
  // unloaded, recording, processing or ready.
  readonly property string state: {
    switch (root.service) {
    case "missing": return "missing"
    case "failed": return "failed"
    case "activating": return "starting"
    case "deactivating": return "stopping"
    case "active": return root.recording ? "recording" : root.processing ? "processing" : root.unloaded ? "unloaded" : "ready"
    default: return "stopped"
    }
  }

  // Runs one of hyprwhspr's commands.
  function hyprwhspr(args) {
    Quickshell.execDetached(["hyprwhspr"].concat(args))
  }

  // Runs systemctl on the unit (enable, disable, restart), with extra flags
  // such as --now.
  function systemctl(action, flags) {
    Quickshell.execDetached(["systemctl", "--user", action].concat(flags ?? []).concat(["hyprwhspr.service"]))
  }

  // Starts a recording, or stops the one going on (it's then transcribed and
  // typed). While the service is stopped or its model unloaded, brings it up
  // instead, as the daemon can't record yet.
  function record() {
    if (root.on) root.hyprwhspr(["record", "toggle"])
    else root.turnOn()
  }

  // Stops the recording going on without transcribing it.
  function cancel() {
    if (root.recording) root.hyprwhspr(["record", "cancel"])
  }

  // Enables and starts the service, so it also starts with the next session,
  // or loads the model back when only that was unloaded (enabling the unit
  // too, in case it was started by hand).
  function turnOn() {
    if (root.running && root.unloaded) {
      root.hyprwhspr(["model", "reload"])
      root.systemctl("enable")
    } else if (!root.running) root.systemctl("enable", ["--now"])
  }

  // Stops and disables the service, which frees the model with it and keeps
  // it off after a restart.
  function turnOff() {
    root.systemctl("disable", ["--now"])
  }

  // Frees the model (and the GPU) while the service keeps running.
  function unloadModel() {
    if (root.on) root.hyprwhspr(["model", "unload"])
  }

  // Loads the model back after unloadModel().
  function reloadModel() {
    if (root.running && root.unloaded) root.hyprwhspr(["model", "reload"])
  }

  // Restarts the service (after a failure, or a change to its config).
  function restart() {
    root.systemctl("restart")
  }

  Process {
    running: root.watching
    command: ["python3", Paths.hyprwhsprWatchScript]

    stdout: SplitParser {
      onRead: line => {
        try {
          const state = JSON.parse(line)
          root.current = {
            service: state.service ?? "inactive",
            recording: state.recording === true,
            processing: state.processing === true,
            unloaded: state.unloaded === true
          }
        } catch (e) {
          console.warn("Hyprwhspr: unreadable line from hyprwhspr-watch.py:", line)
        }
      }
    }
  }

  IpcHandler {
    target: "hyprwhspr"
    enabled: root.watching

    // The state: missing, failed, starting, stopping, stopped, unloaded,
    // recording, processing or ready.
    function status(): string {
      return root.state
    }

    // Starts a recording, or stops the one going on.
    function record(): void {
      root.record()
    }

    // Drops the recording going on.
    function cancel(): void {
      root.cancel()
    }

    // Enables and starts the service (or loads the model back).
    function on(): void {
      root.turnOn()
    }

    // Stops and disables the service, freeing the model.
    function off(): void {
      root.turnOff()
    }

    // Frees the model, keeping the service.
    function unload(): void {
      root.unloadModel()
    }

    // Loads the model back.
    function reload(): void {
      root.reloadModel()
    }

    // Restarts the service.
    function restart(): void {
      root.restart()
    }
  }
}
