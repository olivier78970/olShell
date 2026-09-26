pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The search engines the launcher's web search offers: those of
// Settings.launcherEngines that are on, in their order, with the default
// browser's own default engine where the list has it (read by
// scripts/default-search-engine.py).
Singleton {
  id: root

  // The default browser's default engine ({ name, url }), or null when it
  // can't be read (not read yet, another browser, or a built-in engine the
  // script doesn't know).
  property var browserEngine: null

  // The engine the browser's entry stands for: its own, else
  // Apps.webSearchFallback.
  readonly property var browserOrFallback: root.browserEngine ?? Apps.webSearchFallback

  // The engines to offer, each { name, url, icon }.
  readonly property var engines: Settings.launcherEngines
    .filter(engine => engine.on)
    .map(engine => {
      const resolved = engine.browser ? root.browserOrFallback : engine
      return { name: resolved.name, url: resolved.url, icon: root.iconOf(resolved.name) }
    })

  // The icon of an engine named `name` (see Apps.webSearchIcons), a magnifier
  // for one without.
  function iconOf(name) {
    const key = Object.keys(Apps.webSearchIcons).find(prefix => name.toLowerCase().startsWith(prefix))
    return key ? Apps.webSearchIcons[key] : "󰍉"
  }

  // Reads the browser's engine again (the launcher and the settings panel do
  // it when they open, in case it changed).
  function refresh() {
    reader.running = true
  }

  Component.onCompleted: root.refresh()

  Process {
    id: reader
    command: ["python3", Paths.defaultSearchEngineScript]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const engine = JSON.parse(this.text)
          root.browserEngine = engine.name && engine.url ? { name: engine.name, url: engine.url } : null
        } catch (error) {
          root.browserEngine = null
        }
      }
    }
  }
}
