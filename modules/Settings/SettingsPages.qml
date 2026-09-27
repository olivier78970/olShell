pragma Singleton

import Quickshell
import qs.config

// What the settings panel is made of that doesn't need the panel itself:
// its categories and pages, the rows holding a setting, and the functions
// putting settings back to their defaults or saving them as defaults. The
// panel is only built while it is open (see SettingsModule.qml), and the
// `settings` IPC calls use these while it isn't.
Singleton {
  id: root

  // The categories, top to bottom in the icon rail. A category with `tabs`
  // shows a tab bar under its name, each tab a page of rows of its own; the
  // others are one page. A row's `category` is the page it's on: the
  // category's id, or its tab's.
  readonly property var categories: [
    { id: "appearance", icon: "󰏘", label: I18n.tr("settings.category.appearance") },
    { id: "text", icon: "󰛖", label: I18n.tr("settings.category.text") },
    { id: "bar", icon: "󰍜", label: I18n.tr("settings.category.bar") },
    { id: "barWidgets", icon: "󰀻", label: I18n.tr("settings.category.barWidgets"), tabs: [
      { id: "layout", label: I18n.tr("settings.tab.layout") },
      { id: "widgetSettings", label: I18n.tr("settings.tab.widgetSettings") }
    ] },
    { id: "wallpaper", icon: "󰋩", label: I18n.tr("settings.category.wallpaper") },
    { id: "theme", icon: "󰸌", label: I18n.tr("settings.category.theme") },
    { id: "notifications", icon: "󰂚", label: I18n.tr("settings.category.notifications") },
    { id: "osd", icon: "󰕾", label: I18n.tr("settings.category.osd") },
    { id: "lock", icon: "󰌾", label: I18n.tr("settings.category.lock") },
    { id: "launcher", icon: "󰍉", label: I18n.tr("settings.category.launcher") },
    { id: "general", icon: "󰒓", label: I18n.tr("settings.category.general") }
  ]

  // Every page of rows, by id, in the order of the rail and of the tabs.
  readonly property var pages: root.categories.reduce((pages, category) => pages.concat(category.tabs ? category.tabs.map(tab => tab.id) : [category.id]), [])

  // The rows of every category that hold a setting of their own, top to
  // bottom (the panel adds its engine, added-app and defaults rows). Sliders
  // take their range from Settings.limits.
  readonly property var rows: [
    { key: "radius", category: "appearance", kind: "slider", label: I18n.tr("settings.radius"), step: 1, format: v => v + " px" },
    { key: "language", category: "general", kind: "choice", label: I18n.tr("settings.language") },
    { key: "screenshotDir", category: "general", kind: "path", label: I18n.tr("settings.screenshotDir") },
    { key: "factoryAll", category: "general", kind: "factoryAll", label: I18n.tr("settings.factoryAll") },
    { key: "opacity", category: "appearance", kind: "slider", label: I18n.tr("settings.opacity"), step: 0.05, format: v => Math.round(v * 100) + " %" },
    { key: "spacing", category: "appearance", kind: "slider", label: I18n.tr("settings.spacing"), step: 1, format: v => v + " px" },
    { key: "barAutoHideRow", category: "bar", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.barAutoHide"), toggles: [
      { key: "barAutoHide", text: "" }
    ] },
    { key: "barAutoHideAnimatedRow", category: "bar", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.barAutoHideAnimated"), toggles: [
      { key: "barAutoHideAnimated", text: "" }
    ] },
    { key: "barAutoHideDuration", category: "bar", kind: "slider", label: I18n.tr("settings.barAutoHideDuration"), step: 10, format: v => v + " ms" },
    { key: "barAutoHideDelay", category: "bar", kind: "slider", label: I18n.tr("settings.barAutoHideDelay"), step: 50, format: v => v + " ms" },
    { key: "barPosition", category: "bar", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.barPosition") },
    { key: "barHeight", category: "bar", kind: "slider", label: I18n.tr("settings.barHeight"), step: 1, format: v => v + " px" },
    { key: "barMarginTop", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginTop"), step: 1, format: v => v + " px" },
    { key: "barMarginBottom", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginBottom"), step: 1, format: v => v + " px" },
    { key: "barMarginLeft", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginLeft"), step: 5, format: v => v + " px" },
    { key: "barMarginRight", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginRight"), step: 5, format: v => v + " px" },
    { key: "workspaceCount", category: "widgetSettings", kind: "slider", title: I18n.tr("settings.category.workspaces"), label: I18n.tr("settings.workspaceCount"), tooltip: I18n.tr("settings.workspaceCount.tooltip"), step: 1, format: v => String(v) },
    { key: "workspaceCountFromHyprlandRow", category: "widgetSettings", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.workspaceCountFromHyprland"), toggles: [
      { key: "workspaceCountFromHyprland", text: "" }
    ] },
    { key: "barStyle", category: "bar", kind: "buttons", label: I18n.tr("settings.barStyle") },
    { key: "borderWidth", category: "appearance", kind: "slider", label: I18n.tr("settings.borderWidth"), step: 1, format: v => v + " px" },
    { key: "borderOpaqueRow", category: "appearance", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.borderOpaque"), toggles: [
      { key: "borderOpaque", text: "" }
    ] },
    { key: "blurRow", category: "appearance", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.blur"), toggles: [
      { key: "blur", text: "" }
    ] },
    { key: "panelGap", category: "appearance", kind: "slider", label: I18n.tr("settings.panelGap"), step: 1, format: v => v + " px" },
    { key: "curvedJoinsRow", category: "appearance", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.curvedJoins"), toggles: [
      { key: "curvedJoins", text: "" }
    ] },
    { key: "curvedJoinsRadius", category: "appearance", kind: "slider", label: I18n.tr("settings.curvedJoinsRadius"), step: 1, format: v => v + " px" },
    { key: "curvedJoinsRadiusSameRow", category: "appearance", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.curvedJoinsRadiusSame"), toggles: [
      { key: "curvedJoinsRadiusSame", text: "" }
    ] },
    { key: "fontSize", category: "text", kind: "slider", stepper: true, label: I18n.tr("settings.fontSize"), step: 1, format: v => v + " px" },
    { key: "fontWeight", category: "text", kind: "slider", label: I18n.tr("settings.fontWeight"), step: 100, format: v => I18n.tr("settings.weight." + v) },
    { key: "fontLetterSpacing", category: "text", kind: "slider", stepper: true, label: I18n.tr("settings.fontLetterSpacing"), step: 0.5, format: v => v.toFixed(1) + " px" },
    { key: "fontCaps", category: "text", kind: "buttons", label: I18n.tr("settings.fontCaps") },
    { key: "fontStyle", category: "text", kind: "toggles", label: I18n.tr("settings.fontStyle"), toggles: [
      { key: "fontItalic", text: I18n.tr("settings.fontItalic"), italic: true },
      { key: "fontUnderline", text: I18n.tr("settings.fontUnderline"), underline: true },
      { key: "fontOutline", text: I18n.tr("settings.fontOutline") }
    ] },
    { key: "fontFamily", category: "text", kind: "dropdown", label: I18n.tr("settings.fontFamily") },
    { key: "barLayout", category: "layout", kind: "layoutEditor", label: "" },
    { key: "wallpaperTransition", category: "wallpaper", kind: "dropdown", label: I18n.tr("settings.wallpaperTransition") },
    { key: "wallpaperDuration", category: "wallpaper", kind: "slider", label: I18n.tr("settings.wallpaperDuration"), step: 0.5, format: v => v.toFixed(1) + " s" },
    { key: "themeMode", category: "theme", kind: "buttons", title: I18n.tr("settings.theme.all"), label: I18n.tr("settings.themeMode") },
    { key: "themePill", category: "theme", kind: "dropdown", label: I18n.tr("settings.themePill") },
    { key: "matugenScheme", category: "theme", kind: "dropdown", title: I18n.tr("settings.matugen"), label: I18n.tr("settings.matugenScheme") },
    { key: "matugenSource", category: "theme", kind: "dropdown", label: I18n.tr("settings.matugenSource") },
    { key: "matugenContrast", category: "theme", kind: "slider", label: I18n.tr("settings.matugenContrast"), step: 0.1, format: v => v === 0 ? I18n.tr("settings.matugen.standard") : "+" + Math.round(v * 100) + " %" },
    { key: "matugenLightness", category: "theme", kind: "slider", label: I18n.tr("settings.matugenLightness"), step: 0.1, format: v => v === 0 ? I18n.tr("settings.matugen.standard") : (v > 0 ? "+" : "") + Math.round(v * 100) + " %" },
    { key: "matugenAccent", category: "theme", kind: "buttons", label: I18n.tr("settings.matugenAccent") },
    { key: "themeAccent", category: "theme", kind: "buttons", title: I18n.tr("settings.theme.fixed"), label: I18n.tr("settings.themeAccent") },
    { key: "themeExactAppsRow", category: "theme", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.themeExactApps"), toggles: [
      { key: "themeExactApps", text: "" }
    ] },
    { key: "customBackground", category: "theme", kind: "path", swatch: true, title: I18n.tr("settings.theme.custom"), label: I18n.tr("settings.custom.background") },
    { key: "customPill", category: "theme", kind: "path", swatch: true, label: I18n.tr("settings.custom.pill") },
    { key: "customBorder", category: "theme", kind: "path", swatch: true, label: I18n.tr("settings.custom.border") },
    { key: "customText", category: "theme", kind: "path", swatch: true, label: I18n.tr("settings.custom.text") },
    { key: "customAccent", category: "theme", kind: "path", swatch: true, label: I18n.tr("settings.custom.accent") },
    { key: "customCopy", category: "theme", kind: "action", label: I18n.tr("settings.custom.copy") },
    { key: "matugenAppsRow", category: "theme", kind: "toggles", title: I18n.tr("settings.matugenApps.title"), label: I18n.tr("settings.matugenApps"), toggles: [
      { key: "matugenHyprland", text: "Hyprland" },
      { key: "matugenZen", text: "Zen" },
      { key: "matugenAlacritty", text: "Alacritty" },
      { key: "matugenGtk", text: "GTK" },
      { key: "matugenQt", text: "Qt" },
      { key: "matugenStarship", text: "Starship" }
    ] },
    { key: "notificationTimeout", category: "notifications", kind: "slider", label: I18n.tr("settings.notificationTimeout"), step: 1, format: v => v + " s" },
    { key: "notificationMax", category: "notifications", kind: "slider", label: I18n.tr("settings.notificationMax"), step: 1, format: v => String(v) },
    { key: "notificationPosition", category: "notifications", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.notificationPosition") },
    { key: "notificationDndRow", category: "notifications", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.notificationDnd"), toggles: [
      { key: "notificationDnd", text: "" }
    ] },
    { key: "notificationActions", category: "notifications", kind: "action", label: I18n.tr("settings.notificationActions") },
    { key: "volumeOsdPosition", category: "osd", kind: "dropdown", positionIcon: true, title: I18n.tr("settings.osd.volume"), label: I18n.tr("settings.osdPosition") },
    { key: "volumeOsdMargin", category: "osd", kind: "slider", label: I18n.tr("settings.osdMargin"), step: 5, format: v => v + " px" },
    { key: "lockKeysOsdPosition", category: "osd", kind: "dropdown", positionIcon: true, title: I18n.tr("settings.osd.lockKeys"), label: I18n.tr("settings.osdPosition") },
    { key: "lockKeysOsdMargin", category: "osd", kind: "slider", label: I18n.tr("settings.osdMargin"), step: 5, format: v => v + " px" },
    { key: "lockTimeout", category: "lock", kind: "slider", label: I18n.tr("settings.lockTimeout"), step: 1, format: v => v === 0 ? I18n.tr("settings.lockTimeout.never") : v + " min" },
    { key: "launcherTab", category: "launcher", kind: "buttons", label: I18n.tr("settings.launcherTab") },
    { key: "launcherGamesDir", category: "launcher", kind: "path", label: I18n.tr("settings.launcherGamesDir") },
    { key: "launcherResults", category: "launcher", kind: "slider", label: I18n.tr("settings.launcherResults"), step: 1, format: v => String(v) },
    { key: "clockDate", category: "widgetSettings", kind: "dropdown", title: I18n.tr("settings.category.clock"), label: I18n.tr("settings.clockDate") },
    { key: "clockSecondsRow", category: "widgetSettings", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.clockSeconds"), toggles: [
      { key: "clockSeconds", text: "" }
    ] },
    { key: "zoomMax", category: "widgetSettings", kind: "slider", title: I18n.tr("settings.category.zoom"), label: I18n.tr("settings.zoomMax"), step: 1, format: v => "×" + v },
    { key: "zoomStep", category: "widgetSettings", kind: "slider", label: I18n.tr("settings.zoomStep"), step: 0.1, format: v => v.toFixed(1) },
    { key: "zoomBlocksInputRow", category: "widgetSettings", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.zoomBlocksInput"), toggles: [
      { key: "zoomBlocksInput", text: "" }
    ] }
  ]

  // Puts every setting, and the language, back to the user's own defaults (the
  // built-in ones for what has none).
  function resetAll() {
    Settings.restoreDefaults(Object.keys(Settings.defaults), "mine")
    I18n.select(Settings.userDefaults.language ?? "auto")
  }

  // The settings a category holds, by key: the ones its rows change (the
  // widgets category has the bar's layout lists). The language, which the
  // general category also holds, is not a setting: see the functions below.
  function keysOf(categoryId) {
    if (categoryId === "layout") return ["barLeft", "barCenter", "barRight", "barDividers", "barCollapsed", "barGroupsOff"]
    const keys = []
    for (const row of root.rows) {
      if (row.category !== categoryId) continue
      if (Settings.defaults[row.key] !== undefined) keys.push(row.key)
      for (const toggle of row.toggles ?? []) keys.push(toggle.key)
    }
    // The launcher's engines have a row each, none named after the setting.
    if (categoryId === "launcher") keys.push("launcherEngines")
    // Nor do the theme's added apps.
    if (categoryId === "theme") keys.push("matugenApps")
    return keys
  }

  // Saves the current values of a category as the user's own defaults.
  function saveDefaults(categoryId) {
    Settings.saveDefaults(root.keysOf(categoryId), categoryId === "general" ? { language: I18n.setting } : {})
  }

  // Puts a category back to the user's own defaults ("mine"; the built-in
  // ones for what has none) or to the built-in ones ("factory").
  function restoreDefaults(categoryId, source) {
    Settings.restoreDefaults(root.keysOf(categoryId), source)
    if (categoryId !== "general") return
    const saved = source === "mine" ? Settings.userDefaults.language : undefined
    I18n.select(saved ?? "auto")
  }

  // Puts every setting, and the language, back to the built-in defaults and
  // saves them as the user's defaults too (as for a category), and forgets
  // where turned-off widgets were.
  function factoryResetAll() {
    const keys = Object.keys(Settings.defaults)
    Settings.restoreDefaults(keys, "factory")
    I18n.select("auto")
    Settings.forgetPlaces()
    Settings.saveDefaults(keys, { language: "auto" })
  }
}
