pragma Singleton

import Quickshell

// Selectable themes, in the order shown by the theme panel. "auto" has no
// colors of its own: it uses the palette matugen generated from the current
// wallpaper (see GeneratedColors.qml). The others are fixed palettes, using
// the same five roles as GeneratedColors.json.template.
Singleton {
  readonly property var presets: [
    {
      // Named and described by I18n ("theme.auto", "theme.autoDescription").
      id: "auto"
    },
    {
      id: "catppuccin-mocha",
      name: "Catppuccin Mocha",
      colors: { backgroundColor: "#1e1e2e", borderColor: "#45475a", textColor: "#cdd6f4", accentColor: "#89b4fa", pillColor: "#313244" }
    },
    {
      id: "dracula",
      name: "Dracula",
      colors: { backgroundColor: "#282a36", borderColor: "#44475a", textColor: "#f8f8f2", accentColor: "#bd93f9", pillColor: "#343746" }
    },
    {
      id: "nord",
      name: "Nord",
      colors: { backgroundColor: "#2e3440", borderColor: "#4c566a", textColor: "#eceff4", accentColor: "#88c0d0", pillColor: "#3b4252" }
    },
    {
      id: "gruvbox-dark",
      name: "Gruvbox Dark",
      colors: { backgroundColor: "#282828", borderColor: "#504945", textColor: "#ebdbb2", accentColor: "#fabd2f", pillColor: "#3c3836" }
    },
    {
      id: "tokyo-night",
      name: "Tokyo Night",
      colors: { backgroundColor: "#1a1b26", borderColor: "#414868", textColor: "#c0caf5", accentColor: "#7aa2f7", pillColor: "#24283b" }
    },
    {
      id: "solarized-dark",
      name: "Solarized Dark",
      colors: { backgroundColor: "#002b36", borderColor: "#586e75", textColor: "#93a1a1", accentColor: "#268bd2", pillColor: "#073642" }
    },
    {
      id: "one-dark",
      name: "One Dark",
      colors: { backgroundColor: "#282c34", borderColor: "#4b5263", textColor: "#abb2bf", accentColor: "#61afef", pillColor: "#333842" }
    },
    {
      id: "rose-pine",
      name: "Rosé Pine",
      colors: { backgroundColor: "#191724", borderColor: "#403d52", textColor: "#e0def4", accentColor: "#c4a7e7", pillColor: "#26233a" }
    },
    {
      id: "everforest-dark",
      name: "Everforest Dark",
      colors: { backgroundColor: "#2d353b", borderColor: "#475258", textColor: "#d3c6aa", accentColor: "#a7c080", pillColor: "#343f44" }
    },
    {
      id: "kanagawa",
      name: "Kanagawa",
      colors: { backgroundColor: "#1f1f28", borderColor: "#54546d", textColor: "#dcd7ba", accentColor: "#7e9cd8", pillColor: "#2a2a37" }
    }
  ]

  // Falls back to "auto" for an unknown id (e.g. a preset removed since the
  // selection was saved).
  function byId(id) {
    return presets.find(preset => preset.id === id) ?? presets[0]
  }
}
