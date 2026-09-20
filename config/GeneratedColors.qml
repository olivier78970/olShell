pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Provides the shell's palette: either the fixed colors of the theme chosen
// in the theme panel (see ThemeState), or, for "auto", GeneratedColors.json,
// which matugen regenerates from the current wallpaper (see
// matugen/GeneratedColors.json.template and matugen/quickshell.toml).
// This file itself is static and never rewritten: FileView picks up changes to the JSON data file
// without Quickshell treating it as a source-file edit, so applying a
// wallpaper never triggers a full engine reload (which would reset
// unrelated singleton state, e.g. hiding an open panel).
Singleton {
  id: root

  // Fixed colors of the selected theme, or undefined for "auto", in which
  // case the matugen palette from the JSON below is used.
  readonly property var preset: ThemeState.active.colors

  // The matugen palette regardless of selected theme, for the theme panel's
  // "auto" preview.
  readonly property var matugenColors: ({
    backgroundColor: file.adapter.backgroundColor,
    borderColor: file.adapter.borderColor,
    textColor: file.adapter.textColor,
    accentColor: file.adapter.accentColor,
    pillColor: file.adapter.pillColor
  })

  // Not readonly: Behavior needs write access to animate between values.
  property color backgroundColor: root.preset ? root.preset.backgroundColor : file.adapter.backgroundColor
  property color borderColor: root.preset ? root.preset.borderColor : file.adapter.borderColor
  property color textColor: root.preset ? root.preset.textColor : file.adapter.textColor
  property color accentColor: root.preset ? root.preset.accentColor : file.adapter.accentColor
  property color pillColor: root.preset ? root.preset.pillColor : file.adapter.pillColor

  // Fades the whole shell's theme into the new palette instead of
  // snapping, whenever a wallpaper change regenerates the JSON above or
  // another theme is selected.
  Behavior on backgroundColor { ColorAnimation { duration: 400 } }
  Behavior on borderColor { ColorAnimation { duration: 400 } }
  Behavior on textColor { ColorAnimation { duration: 400 } }
  Behavior on accentColor { ColorAnimation { duration: 400 } }
  Behavior on pillColor { ColorAnimation { duration: 400 } }

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
    }
  }
}
