pragma Singleton

import QtQuick
import Quickshell

// Selectable themes, in the order shown by the theme panel. "auto" has no
// colors of its own: it uses the palette matugen generated from the current
// wallpaper (see GeneratedColors.qml). "custom" takes its five colors from
// the settings (Settings.customBackground...). The others are fixed themes,
// each with a dark version and, when the theme has an official one, a light
// version (picked by Settings.themeMode). A version has four colors of the
// five roles of matugen/quickshell-theme.json.template, and its accent is
// one of the theme's named `accents` (`accent` by default, the one picked in
// Settings.themeAccent when the theme has it).
//
// The accents are named by the color they are, for every theme alike
// (Catppuccin's mauve is "purple", Nord's frost "cyan"...), so the accent
// picked stays the same kind of color from one theme to the next.
Singleton {
  id: root

  // The names an accent can have, in the order the settings list them.
  readonly property var accentNames: ["blue", "purple", "pink", "red", "orange", "yellow", "green", "cyan"]

  readonly property var presets: [
    {
      // Named and described by I18n ("theme.auto", "theme.autoDescription").
      id: "auto"
    },
    {
      id: "catppuccin-mocha",
      dark: {
        name: "Catppuccin Mocha",
        colors: { backgroundColor: "#1e1e2e", borderColor: "#45475a", textColor: "#cdd6f4", pillColor: "#313244" },
        accent: "blue",
        accents: { blue: "#89b4fa", purple: "#cba6f7", pink: "#f5c2e7", red: "#f38ba8", orange: "#fab387", yellow: "#f9e2af", green: "#a6e3a1", cyan: "#94e2d5" }
      },
      light: {
        name: "Catppuccin Latte",
        colors: { backgroundColor: "#eff1f5", borderColor: "#bcc0cc", textColor: "#4c4f69", pillColor: "#e6e9ef" },
        accent: "blue",
        accents: { blue: "#1e66f5", purple: "#8839ef", pink: "#ea76cb", red: "#d20f39", orange: "#fe640b", yellow: "#df8e1d", green: "#40a02b", cyan: "#179299" }
      }
    },
    {
      id: "dracula",
      dark: {
        name: "Dracula",
        colors: { backgroundColor: "#282a36", borderColor: "#44475a", textColor: "#f8f8f2", pillColor: "#343746" },
        accent: "purple",
        accents: { purple: "#bd93f9", pink: "#ff79c6", red: "#ff5555", orange: "#ffb86c", yellow: "#f1fa8c", green: "#50fa7b", cyan: "#8be9fd" }
      }
    },
    {
      id: "nord",
      dark: {
        name: "Nord",
        colors: { backgroundColor: "#2e3440", borderColor: "#4c566a", textColor: "#eceff4", pillColor: "#3b4252" },
        accent: "cyan",
        accents: { cyan: "#88c0d0", blue: "#81a1c1", purple: "#b48ead", red: "#bf616a", orange: "#d08770", yellow: "#ebcb8b", green: "#a3be8c" }
      }
    },
    {
      id: "gruvbox-dark",
      dark: {
        name: "Gruvbox Dark",
        colors: { backgroundColor: "#282828", borderColor: "#504945", textColor: "#ebdbb2", pillColor: "#3c3836" },
        accent: "yellow",
        accents: { yellow: "#fabd2f", blue: "#83a598", purple: "#d3869b", red: "#fb4934", orange: "#fe8019", green: "#b8bb26", cyan: "#8ec07c" }
      },
      light: {
        name: "Gruvbox Light",
        colors: { backgroundColor: "#fbf1c7", borderColor: "#d5c4a1", textColor: "#3c3836", pillColor: "#ebdbb2" },
        accent: "yellow",
        accents: { yellow: "#b57614", blue: "#076678", purple: "#8f3f71", red: "#9d0006", orange: "#af3a03", green: "#79740e", cyan: "#427b58" }
      }
    },
    {
      id: "tokyo-night",
      dark: {
        name: "Tokyo Night",
        colors: { backgroundColor: "#1a1b26", borderColor: "#414868", textColor: "#c0caf5", pillColor: "#24283b" },
        accent: "blue",
        accents: { blue: "#7aa2f7", purple: "#bb9af7", red: "#f7768e", orange: "#ff9e64", yellow: "#e0af68", green: "#9ece6a", cyan: "#7dcfff" }
      },
      light: {
        name: "Tokyo Night Day",
        colors: { backgroundColor: "#e1e2e7", borderColor: "#a8aecb", textColor: "#3760bf", pillColor: "#d0d5e3" },
        accent: "blue",
        accents: { blue: "#2e7de9", purple: "#9854f1", red: "#f52a65", orange: "#b15c00", yellow: "#8c6c3e", green: "#587539", cyan: "#007197" }
      }
    },
    {
      id: "solarized-dark",
      dark: {
        name: "Solarized Dark",
        colors: { backgroundColor: "#002b36", borderColor: "#586e75", textColor: "#93a1a1", pillColor: "#073642" },
        accent: "blue",
        accents: { blue: "#268bd2", purple: "#6c71c4", pink: "#d33682", red: "#dc322f", orange: "#cb4b16", yellow: "#b58900", green: "#859900", cyan: "#2aa198" }
      },
      light: {
        name: "Solarized Light",
        colors: { backgroundColor: "#fdf6e3", borderColor: "#93a1a1", textColor: "#586e75", pillColor: "#eee8d5" },
        accent: "blue",
        accents: { blue: "#268bd2", purple: "#6c71c4", pink: "#d33682", red: "#dc322f", orange: "#cb4b16", yellow: "#b58900", green: "#859900", cyan: "#2aa198" }
      }
    },
    {
      id: "one-dark",
      dark: {
        name: "One Dark",
        colors: { backgroundColor: "#282c34", borderColor: "#4b5263", textColor: "#abb2bf", pillColor: "#333842" },
        accent: "blue",
        accents: { blue: "#61afef", purple: "#c678dd", red: "#e06c75", orange: "#d19a66", yellow: "#e5c07b", green: "#98c379", cyan: "#56b6c2" }
      },
      light: {
        name: "One Light",
        colors: { backgroundColor: "#fafafa", borderColor: "#d3d3d4", textColor: "#383a42", pillColor: "#eaeaeb" },
        accent: "blue",
        accents: { blue: "#4078f2", purple: "#a626a4", red: "#e45649", orange: "#986801", yellow: "#c18401", green: "#50a14f", cyan: "#0184bc" }
      }
    },
    {
      id: "rose-pine",
      dark: {
        name: "Rosé Pine",
        colors: { backgroundColor: "#191724", borderColor: "#403d52", textColor: "#e0def4", pillColor: "#26233a" },
        accent: "purple",
        accents: { purple: "#c4a7e7", blue: "#31748f", pink: "#ebbcba", red: "#eb6f92", yellow: "#f6c177", cyan: "#9ccfd8" }
      },
      light: {
        name: "Rosé Pine Dawn",
        colors: { backgroundColor: "#faf4ed", borderColor: "#dfdad9", textColor: "#575279", pillColor: "#f2e9e1" },
        accent: "purple",
        accents: { purple: "#907aa9", blue: "#286983", pink: "#d7827e", red: "#b4637a", yellow: "#ea9d34", cyan: "#56949f" }
      }
    },
    {
      id: "everforest-dark",
      dark: {
        name: "Everforest Dark",
        colors: { backgroundColor: "#2d353b", borderColor: "#475258", textColor: "#d3c6aa", pillColor: "#343f44" },
        accent: "green",
        accents: { green: "#a7c080", blue: "#7fbbb3", purple: "#d699b6", red: "#e67e80", orange: "#e69875", yellow: "#dbbc7f", cyan: "#83c092" }
      },
      light: {
        name: "Everforest Light",
        colors: { backgroundColor: "#fdf6e3", borderColor: "#bdc3af", textColor: "#5c6a72", pillColor: "#f4f0d9" },
        accent: "green",
        accents: { green: "#8da101", blue: "#3a94c5", purple: "#df69ba", red: "#f85552", orange: "#f57d26", yellow: "#dfa000", cyan: "#35a77c" }
      }
    },
    {
      id: "kanagawa",
      dark: {
        name: "Kanagawa",
        colors: { backgroundColor: "#1f1f28", borderColor: "#54546d", textColor: "#dcd7ba", pillColor: "#2a2a37" },
        accent: "blue",
        accents: { blue: "#7e9cd8", purple: "#957fb8", pink: "#d27e99", red: "#ff5d62", orange: "#ffa066", yellow: "#e6c384", green: "#98bb6c", cyan: "#7aa89f" }
      },
      light: {
        name: "Kanagawa Lotus",
        colors: { backgroundColor: "#f2ecbc", borderColor: "#a09cac", textColor: "#545464", pillColor: "#e5ddb0" },
        accent: "blue",
        accents: { blue: "#4d699b", purple: "#624c83", pink: "#b35b79", red: "#c84053", orange: "#cc6d00", yellow: "#77713f", green: "#6f894e", cyan: "#597b75" }
      }
    },
    {
      // Named by I18n ("theme.custom"); its colors are settings.
      id: "custom"
    }
  ]

  // The theme `id` as it is used right now: { id, name, kind ("auto",
  // "fixed" or "custom"), mode ("dark" or "light"), hasLight, and for the
  // fixed and custom themes colors (the five roles, with the widget
  // background level of Settings.themePill applied), baseColors (the same
  // without it) and, for a fixed one,
  // accents (its named accents) and accent (the name of the one in use) }.
  // An unknown id (e.g. a theme removed since it was chosen) is "auto".
  function resolve(id) {
    const preset = root.presets.find(theme => theme.id === id) ?? root.presets[0]
    if (preset.id === "auto")
      return { id: "auto", name: I18n.tr("theme.auto"), kind: "auto", mode: Settings.themeMode, hasLight: true }
    if (preset.id === "custom") {
      const colors = {
        backgroundColor: Settings.customBackground,
        borderColor: Settings.customBorder,
        textColor: Settings.customText,
        accentColor: Settings.customAccent,
        pillColor: Settings.customPill
      }
      return { id: "custom", name: I18n.tr("theme.custom"), kind: "custom", mode: root.modeOf(colors), hasLight: false, colors: root.withPillLevel(colors), baseColors: colors }
    }
    const hasLight = preset.light !== undefined
    const mode = hasLight && Settings.themeMode === "light" ? "light" : "dark"
    const version = preset[mode]
    const accent = version.accents[Settings.themeAccent] !== undefined ? Settings.themeAccent : version.accent
    const colors = Object.assign({ accentColor: version.accents[accent] }, version.colors)
    return { id: preset.id, name: version.name, kind: "fixed", mode: mode, hasLight: hasLight, colors: root.withPillLevel(colors), baseColors: colors, accents: version.accents, accent: accent }
  }

  // `colors` with its widget background moved toward the background (the
  // two lower levels) or toward the text (the two higher ones), for the
  // level picked in Settings.themePill.
  function withPillLevel(colors) {
    const toward = {
      lowest: [colors.backgroundColor, 0.75],
      low: [colors.backgroundColor, 0.4],
      high: [colors.textColor, 0.08],
      highest: [colors.textColor, 0.16]
    }[Settings.themePill]
    if (toward === undefined)
      return colors
    const target = Qt.color(toward[0])
    const pill = Qt.tint(Qt.color(colors.pillColor), Qt.rgba(target.r, target.g, target.b, toward[1]))
    return Object.assign({}, colors, { pillColor: pill.toString() })
  }

  // Whether `colors` make a dark or a light theme, by how light their
  // background is.
  function modeOf(colors) {
    return Qt.color(colors.backgroundColor).hslLightness > 0.5 ? "light" : "dark"
  }
}
