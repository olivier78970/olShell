pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Provides the shell's palette: either the fixed colors of the theme chosen
// in the theme panel (see ThemeState), or, for "auto", GeneratedColors.json,
// which matugen regenerates from the current wallpaper (see
// matugen/quickshell-theme.json.template and matugen/quickshell.toml).
// This file itself is static and never rewritten: FileView picks up changes to the JSON data file
// without Quickshell treating it as a source-file edit, so applying a
// wallpaper never triggers a full engine reload (which would reset
// unrelated singleton state, e.g. hiding an open panel).
Singleton {
  id: root

  // Fixed colors of the selected theme, or undefined for "auto", in which
  // case the matugen palette from the JSON below is used.
  readonly property var preset: ThemeState.active.colors

  // The matugen colors the accent can be (see Settings.choices.matugenAccent),
  // also for the settings row's swatches. A file written before the other
  // candidates were added only has the primary one.
  readonly property var matugenAccents: ({
    primary: file.adapter.accentColor,
    secondary: file.adapter.accentSecondary || file.adapter.accentColor,
    tertiary: file.adapter.accentTertiary || file.adapter.accentColor
  })

  // The matugen accent and pill colors picked in the settings
  // (Settings.matugenAccent and themePill). A file written before the
  // other candidates were added only has the default ones.
  readonly property string matugenAccent: root.matugenAccents[Settings.matugenAccent] || file.adapter.accentColor
  readonly property string themePill: ({
    lowest: file.adapter.pillLowest,
    low: file.adapter.pillLow,
    normal: file.adapter.pillColor,
    high: file.adapter.pillHigh,
    highest: file.adapter.pillHighest
  })[Settings.themePill] || file.adapter.pillColor

  // The matugen palette regardless of selected theme, for the theme panel's
  // "auto" preview.
  readonly property var matugenColors: ({
    backgroundColor: file.adapter.backgroundColor,
    borderColor: file.adapter.borderColor,
    textColor: file.adapter.textColor,
    accentColor: root.matugenAccent,
    pillColor: root.themePill
  })

  // The same with matugen's own widget background, whatever level is
  // picked, for copying into the custom theme (which applies its own).
  readonly property var matugenBaseColors: Object.assign({}, root.matugenColors, { pillColor: file.adapter.pillColor })

  // Not readonly: Behavior needs write access to animate between values.
  property color backgroundColor: root.preset ? root.preset.backgroundColor : file.adapter.backgroundColor
  property color borderColor: root.preset ? root.preset.borderColor : file.adapter.borderColor
  property color textColor: root.preset ? root.preset.textColor : file.adapter.textColor
  property color accentColor: root.preset ? root.preset.accentColor : root.matugenAccent
  property color pillColor: root.preset ? root.preset.pillColor : root.themePill

  // Fades the whole shell's theme into the new palette instead of
  // snapping, whenever a wallpaper change regenerates the JSON above or
  // another theme is selected.
  readonly property int fadeDuration: 200
  Behavior on backgroundColor { ColorAnimation { duration: root.fadeDuration } }
  Behavior on borderColor { ColorAnimation { duration: root.fadeDuration } }
  Behavior on textColor { ColorAnimation { duration: root.fadeDuration } }
  Behavior on accentColor { ColorAnimation { duration: root.fadeDuration } }
  Behavior on pillColor { ColorAnimation { duration: root.fadeDuration } }

  FileView {
    id: file
    path: Paths.generatedColors
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      property string backgroundColor: "#1e1e2e"
      property string borderColor: "#313244"
      property string textColor: "#cdd6f4"
      property string accentColor: "#89b4fa"
      property string pillColor: "#313244"
      // The other accent and pill candidates (see matugenAccent and
      // themePill above).
      property string accentSecondary: ""
      property string accentTertiary: ""
      property string pillLowest: ""
      property string pillLow: ""
      property string pillHigh: ""
      property string pillHighest: ""
    }
  }
}
