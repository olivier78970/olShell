pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Saved configurations, kept in config/Profiles.json: a profile is a named
// snapshot of every setting, the language and the theme in use, which can be
// applied again later to switch between looks. Driven from the settings
// panel's Profiles category, and from outside:
//   quickshell -p . ipc call profiles list            (the names and the current one, as JSON)
//   quickshell -p . ipc call profiles save "<name>"   (the current configuration; replaces a profile of that name)
//   quickshell -p . ipc call profiles apply "<name>"
//   quickshell -p . ipc call profiles remove "<name>"
Singleton {
  id: root

  readonly property int maxNameLength: 40

  // The built-in profile: every setting at its built-in value, the language
  // automatic and the automatic theme. It is not stored, so it can't be
  // deleted or replaced, and a saved profile can't take its name.
  readonly property string factory: "factory"

  // The saved profiles, by name: { values: { setting key: value }, language, theme }.
  readonly property var profiles: file.adapter.profiles ?? ({})
  // The profile names: the built-in one, then the saved ones in alphabetical
  // order.
  readonly property var names: [root.factory].concat(Object.keys(root.profiles).sort((a, b) => a.localeCompare(b)))
  // The profile saved or applied last, or the built-in one when there is
  // none. It says which one the settings started from,
  // not that they still match.
  readonly property string current: root.profiles[file.adapter.current] !== undefined ? file.adapter.current : root.factory

  // The profile `name`, as { values, language, theme }; the built-in one's
  // values are empty, which stands for every setting's built-in value.
  function profileOf(name) {
    if (name === root.factory) return { values: {}, language: "auto", theme: "auto" }
    return root.profiles[name]
  }

  // The language of the profile `name`.
  function language(name) {
    return root.profileOf(name)?.language ?? "auto"
  }

  // Puts the settings `keys` back to their value in the profile `name` (the
  // current one by default): what a page's Reset does.
  function restore(keys, name) {
    const profile = root.profileOf(name ?? root.current)
    for (const setting of keys) {
      if (Settings.defaults[setting] === undefined) continue
      const value = profile?.values[setting]
      Settings.set(setting, value !== undefined ? value : Settings.defaults[setting])
    }
  }

  // The name as it is stored: trimmed and limited in length.
  function clean(name) {
    return String(name ?? "").trim().slice(0, root.maxNameLength)
  }

  // Saves the current configuration as the profile `name`, replacing the
  // one of that name. Returns false for an empty name, or the built-in one's.
  function save(name) {
    const key = root.clean(name)
    if (key === "" || key.toLowerCase() === root.factory) return false
    const values = {}
    for (const setting of Object.keys(Settings.defaults)) {
      const value = Settings.get(setting)
      // A copy, so the profile doesn't change along with a list setting.
      if (value !== undefined) values[setting] = JSON.parse(JSON.stringify(value))
    }
    const all = {}
    for (const other in root.profiles) all[other] = root.profiles[other]
    all[key] = { values: values, language: I18n.setting, theme: ThemeState.active.id }
    file.adapter.profiles = all
    file.adapter.current = key
    file.writeAdapter()
    return true
  }

  // Puts every setting, the language and the theme to those of the profile
  // `name` (the built-in value for a setting it doesn't have, such as one
  // added since). Returns false when there is no such profile.
  function apply(name) {
    const profile = root.profileOf(name)
    if (profile === undefined) return false
    for (const setting of Object.keys(Settings.defaults)) {
      const value = profile.values[setting]
      Settings.set(setting, value !== undefined ? value : Settings.defaults[setting])
    }
    I18n.select(profile.language ?? "auto")
    if (profile.theme !== undefined && profile.theme !== ThemeState.active.id) {
      ThemeState.select(profile.theme)
      Matugen.applyTheme()
    }
    file.adapter.current = name
    file.writeAdapter()
    return true
  }

  // Deletes the profile `name` (not the built-in one). Deleting the current
  // profile applies the built-in one, so the settings match the mark.
  function remove(name) {
    if (root.profiles[name] === undefined) return
    const wasCurrent = name === root.current
    const all = {}
    for (const other in root.profiles) {
      if (other !== name) all[other] = root.profiles[other]
    }
    file.adapter.profiles = all
    if (file.adapter.current === name) file.adapter.current = ""
    file.writeAdapter()
    if (wasCurrent) root.apply(root.factory)
  }

  IpcHandler {
    target: "profiles"

    // The saved profiles' names and the current one, as JSON:
    // { current, names: [] }.
    function list(): string {
      return JSON.stringify({ current: root.current, names: root.names })
    }

    // Saves the current configuration under `name`, replacing that profile.
    function save(name: string): void {
      root.save(name)
    }

    // Switches to the profile `name`.
    function apply(name: string): void {
      root.apply(name)
    }

    // Deletes the profile `name`.
    function remove(name: string): void {
      root.remove(name)
    }
  }

  // The values saved as "my defaults" before profiles existed, turned into a
  // profile of that name once (the file is left as it is).
  FileView {
    id: legacy
    path: Paths.userDefaults
    blockLoading: true
    printErrors: false

    JsonAdapter {
      property var values: ({})
    }
  }

  // Runs once the files are read (a moment after the singleton is created).
  Timer {
    running: true
    interval: 1
    onTriggered: {
      const saved = legacy.adapter.values ?? ({})
      let any = false
      for (const key in saved) any = true
      if (file.adapter.migrated || !any) return
      file.adapter.migrated = true
      if (root.profiles.defaults === undefined) {
        const all = {}
        for (const other in root.profiles) all[other] = root.profiles[other]
        const values = {}
        for (const key of Object.keys(Settings.defaults)) values[key] = saved[key] !== undefined ? saved[key] : Settings.defaults[key]
        all.defaults = { values: values, language: saved.language ?? "auto", theme: "auto" }
        file.adapter.profiles = all
      }
      file.writeAdapter()
    }
  }

  FileView {
    id: file
    path: Paths.profiles
    blockLoading: true
    // The file only exists once a profile has been saved.
    printErrors: false

    JsonAdapter {
      property var profiles: ({})
      property string current: ""
      property bool migrated: false
    }
  }
}
