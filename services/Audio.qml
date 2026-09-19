pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Default output volume/mute state, shared by the bar widget and the OSD.
// A singleton so there is one Pipewire tracker and one IPC target no
// matter how many screens the bar is replicated on.
Singleton {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool sinkReady: root.sink?.ready ?? false
  readonly property real volume: root.sink?.audio?.volume ?? 0
  readonly property bool muted: root.sink?.audio?.muted ?? false
  readonly property int percent: Math.round(root.volume * 100)
  readonly property string icon: root.muted ? "󰝟" : (root.percent === 0 ? "󰖁" : (root.percent >= 50 ? "󰕾" : "󰕿"))

  function adjust(delta) {
    if (!root.sink?.audio) return
    root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta))
  }

  function toggleMute() {
    if (!root.sink?.audio) return
    root.sink.audio.muted = !root.sink.audio.muted
  }

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // External control, e.g. from Hyprland keybinds:
  //   quickshell -p . ipc call volume increase 0.05
  //   quickshell -p . ipc call volume decrease 0.05
  //   quickshell -p . ipc call volume mute
  IpcHandler {
    target: "volume"

    function increase(step: real): void {
      root.adjust(step)
    }

    function decrease(step: real): void {
      root.adjust(-step)
    }

    function mute(): void {
      root.toggleMute()
    }
  }
}
