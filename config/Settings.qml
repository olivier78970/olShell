pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The look-and-feel values the user can adjust from the settings panel,
// saved in Settings.json. Theme reads them from here, so a change shows up
// everywhere at once. The language is handled by I18n.
Singleton {
  id: root

  // What each setting is when nothing has been saved.
  readonly property var defaults: ({
    radius: 5,
    opacity: 0.9,
    spacing: 15,
    barHeight: 40,
    barMarginTop: 5,
    barMarginLeft: 5,
    barMarginRight: 5,
    borderWidth: 2,
    wallpaperTransition: "fade",
    wallpaperDuration: 2
  })

  // [minimum, maximum] of each setting, for the panel's sliders and to keep
  // a hand-edited file from breaking the layout.
  readonly property var limits: ({
    radius: [0, 30],
    opacity: [0.4, 1],
    spacing: [0, 40],
    barHeight: [28, 72],
    barMarginTop: [0, 100],
    barMarginLeft: [0, 300],
    barMarginRight: [0, 300],
    borderWidth: [0, 6],
    wallpaperDuration: [0.5, 10]
  })

  // The values a setting can only take one of, in the order the panel cycles
  // through them. The wallpaper transitions are those of `awww img
  // --transition-type` ("simple" is left out: "fade" is the same, tunable, and
  // "none" already changes the wallpaper at once).
  readonly property var choices: ({
    wallpaperTransition: ["fade", "none", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "outer", "any", "random"]
  })

  // Corner radius of every rounded item, in pixels.
  readonly property int radius: root.valid("radius", file.adapter.radius)
  // Opacity of pills, popups and panels (0 to 1).
  readonly property real opacity: root.valid("opacity", file.adapter.opacity)
  // Space between the widgets of a pill.
  readonly property int spacing: root.valid("spacing", file.adapter.spacing)
  readonly property int barHeight: root.valid("barHeight", file.adapter.barHeight)
  readonly property int barMarginTop: root.valid("barMarginTop", file.adapter.barMarginTop)
  readonly property int barMarginLeft: root.valid("barMarginLeft", file.adapter.barMarginLeft)
  readonly property int barMarginRight: root.valid("barMarginRight", file.adapter.barMarginRight)
  // Width of the outline around surfaces; 0 for none.
  readonly property int borderWidth: root.valid("borderWidth", file.adapter.borderWidth)
  // How awww changes from one wallpaper to the next (one of choices.wallpaperTransition),
  // and how long it takes, in seconds.
  readonly property string wallpaperTransition: root.valid("wallpaperTransition", file.adapter.wallpaperTransition)
  readonly property real wallpaperDuration: root.valid("wallpaperDuration", file.adapter.wallpaperDuration)

  // `value` for setting `key` kept within its limits (the default if it
  // isn't a number), and rounded to whole numbers except for the opacity
  // (hundredths) and the duration (tenths). For a setting with a fixed list of
  // choices, `value` if it is one of them, else the default.
  function valid(key, value) {
    const choices = root.choices[key]
    if (choices !== undefined) return choices.includes(value) ? value : root.defaults[key]
    const [min, max] = root.limits[key]
    if (typeof value !== "number" || isNaN(value)) return root.defaults[key]
    const clamped = Math.max(min, Math.min(max, value))
    if (key === "opacity") return Math.round(clamped * 100) / 100
    return key === "wallpaperDuration" ? Math.round(clamped * 10) / 10 : Math.round(clamped)
  }

  // The current value of setting `key`.
  function get(key) {
    return root[key]
  }

  // Changes a setting and saves it (shortly after the last change, so
  // dragging a slider doesn't write the file for every step).
  function set(key, value) {
    if (root.limits[key] === undefined && root.choices[key] === undefined) return
    file.adapter[key] = root.valid(key, value)
    saveTimer.restart()
  }

  function reset() {
    for (const key in root.defaults) file.adapter[key] = root.defaults[key]
    saveTimer.restart()
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: file.writeAdapter()
  }

  FileView {
    id: file
    path: Paths.settings
    // Read synchronously so saved values are in place from the first frame.
    blockLoading: true

    JsonAdapter {
      property int radius: 5
      property real opacity: 0.9
      property int spacing: 15
      property int barHeight: 40
      property int barMarginTop: 5
      property int barMarginLeft: 5
      property int barMarginRight: 5
      property int borderWidth: 2
      property string wallpaperTransition: "fade"
      property real wallpaperDuration: 2
    }
  }
}
