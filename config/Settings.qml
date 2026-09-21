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
    barMarginBottom: 0,
    barMarginLeft: 5,
    barMarginRight: 5,
    borderWidth: 2,
    fontSize: 18,
    fontFamily: "0xProto Nerd Font",
    fontWeight: 400,
    fontLetterSpacing: 0,
    fontCaps: "none",
    fontItalic: false,
    fontUnderline: false,
    fontOutline: false,
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
    barMarginBottom: [0, 100],
    barMarginLeft: [0, 300],
    barMarginRight: [0, 300],
    borderWidth: [0, 6],
    fontSize: [10, 32],
    fontWeight: [100, 900],
    fontLetterSpacing: [-2, 6],
    wallpaperDuration: [0.5, 10]
  })

  // The values a setting can only take one of, in the order the panel cycles
  // through them. The wallpaper transitions are those of `awww img
  // --transition-type` ("simple" is left out: "fade" is the same, tunable, and
  // "none" already changes the wallpaper at once).
  readonly property var choices: ({
    fontCaps: ["none", "upper", "lower", "small"],
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
  // Extra room kept free below the bar, on top of the compositor's own gaps,
  // before the windows start.
  readonly property int barMarginBottom: root.valid("barMarginBottom", file.adapter.barMarginBottom)
  readonly property int barMarginLeft: root.valid("barMarginLeft", file.adapter.barMarginLeft)
  readonly property int barMarginRight: root.valid("barMarginRight", file.adapter.barMarginRight)
  // Width of the outline around surfaces; 0 for none.
  readonly property int borderWidth: root.valid("borderWidth", file.adapter.borderWidth)
  // Text size in pixels, and the font of all text and icons (a font family
  // name; the icons are Nerd Font glyphs, so a Nerd Font is the safe choice).
  readonly property int fontSize: root.valid("fontSize", file.adapter.fontSize)
  readonly property string fontFamily: root.valid("fontFamily", file.adapter.fontFamily)
  // Text style, applied to all text (and the icons, which are text too): the
  // weight (100 thin to 900 black, 400 normal, 700 bold; a font without that
  // weight uses the nearest it has), the space added between letters in
  // pixels, one of choices.fontCaps (as typed / all upper case / all lower
  // case / small capitals), and italic, underline and outline switches.
  readonly property int fontWeight: root.valid("fontWeight", file.adapter.fontWeight)
  readonly property real fontLetterSpacing: root.valid("fontLetterSpacing", file.adapter.fontLetterSpacing)
  readonly property string fontCaps: root.valid("fontCaps", file.adapter.fontCaps)
  readonly property bool fontItalic: root.valid("fontItalic", file.adapter.fontItalic)
  readonly property bool fontUnderline: root.valid("fontUnderline", file.adapter.fontUnderline)
  readonly property bool fontOutline: root.valid("fontOutline", file.adapter.fontOutline)
  // How awww changes from one wallpaper to the next (one of choices.wallpaperTransition),
  // and how long it takes, in seconds.
  readonly property string wallpaperTransition: root.valid("wallpaperTransition", file.adapter.wallpaperTransition)
  readonly property real wallpaperDuration: root.valid("wallpaperDuration", file.adapter.wallpaperDuration)

  // `value` for setting `key` kept within its limits (the default if it
  // isn't a number), and rounded to whole numbers except for the opacity
  // (hundredths), the duration and the letter spacing (tenths) and the weight
  // (hundreds). For a setting with a fixed list of
  // choices, `value` if it is one of them, else the default. The font family
  // is any non-empty name (whether it is installed isn't checked here), and a
  // yes/no setting is true or false.
  function valid(key, value) {
    if (key === "fontFamily") return typeof value === "string" && value.length > 0 ? value : root.defaults[key]
    // A yes/no setting; a number counts too (0 is off), for the IPC calls.
    if (typeof root.defaults[key] === "boolean") {
      if (typeof value === "number" && !isNaN(value)) return value !== 0
      return typeof value === "boolean" ? value : root.defaults[key]
    }
    const choices = root.choices[key]
    if (choices !== undefined) return choices.includes(value) ? value : root.defaults[key]
    const [min, max] = root.limits[key]
    if (typeof value !== "number" || isNaN(value)) return root.defaults[key]
    const clamped = Math.max(min, Math.min(max, value))
    if (key === "opacity") return Math.round(clamped * 100) / 100
    if (key === "fontWeight") return Math.round(clamped / 100) * 100
    return key === "wallpaperDuration" || key === "fontLetterSpacing" ? Math.round(clamped * 10) / 10 : Math.round(clamped)
  }

  // The current value of setting `key`.
  function get(key) {
    return root[key]
  }

  // Changes a setting and saves it (shortly after the last change, so
  // dragging a slider doesn't write the file for every step).
  function set(key, value) {
    if (root.defaults[key] === undefined) return
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
      property int barMarginBottom: 0
      property int barMarginLeft: 5
      property int barMarginRight: 5
      property int borderWidth: 2
      property int fontSize: 18
      property string fontFamily: "0xProto Nerd Font"
      property int fontWeight: 400
      property real fontLetterSpacing: 0
      property string fontCaps: "none"
      property bool fontItalic: false
      property bool fontUnderline: false
      property bool fontOutline: false
      property string wallpaperTransition: "fade"
      property real wallpaperDuration: 2
    }
  }
}
