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
    { id: "appearanceCategory", icon: "󰏘", label: I18n.tr("settings.category.appearance"), tabs: [
      { id: "appearance", label: I18n.tr("settings.tab.appearance") },
      { id: "blur", label: I18n.tr("settings.tab.blur") },
      { id: "windows", label: I18n.tr("settings.tab.windows") },
      { id: "appOpacity", label: I18n.tr("settings.tab.applications") }
    ] },
    // Animations: the shell's own, and Hyprland's.
    { id: "animationsCategory", icon: "󰗘", label: I18n.tr("settings.category.animations"), tabs: [
      { id: "animations", label: I18n.tr("settings.tab.appearance") },
      { id: "hyprlandAnimations", label: I18n.tr("settings.tab.windows") }
    ] },
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
    { id: "webApps", icon: "󰖟", label: I18n.tr("settings.category.webApps") },
    // Panels: where each opens, then a tab for each panel with settings of
    // its own, named after it.
    { id: "panelsCategory", icon: "󰖲", label: I18n.tr("settings.category.panels"), tabs: [
      { id: "panels", label: I18n.tr("settings.tab.placement") },
      { id: "switcher", label: I18n.tr("settings.placement.switcher") },
      { id: "clockPanel", label: I18n.tr("settings.category.clock") }
    ] },
    // Chat AI: the providers, what the AI may reach, then the question history
    // and the status lines.
    { id: "chatAiCategory", icon: "󰭹", label: I18n.tr("settings.category.chatAi"), tabs: [
      { id: "chatAi", label: I18n.tr("settings.chatAiProviders") },
      { id: "chatAiAccess", label: I18n.tr("settings.tab.chatAiAccess") },
      { id: "chatAiHistory", label: I18n.tr("settings.tab.chatAiHistory") }
    ] },
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
    { key: "blurRow", category: "blur", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.blur"), toggles: [
      { key: "blur", text: "" }
    ] },
    { key: "blurSize", category: "blur", kind: "slider", label: I18n.tr("settings.blurSize"), step: 1, format: v => v + " px" },
    { key: "blurPasses", category: "blur", kind: "slider", label: I18n.tr("settings.blurPasses"), step: 1, format: v => String(v) },
    { key: "blurVibrancy", category: "blur", kind: "slider", label: I18n.tr("settings.blurVibrancy"), step: 0.05, format: v => Math.round(v * 100) + " %" },
    { key: "blurContrast", category: "blur", kind: "slider", label: I18n.tr("settings.blurContrast"), step: 0.05, format: v => Math.round(v * 100) + " %" },
    { key: "blurBrightness", category: "blur", kind: "slider", label: I18n.tr("settings.blurBrightness"), step: 0.05, format: v => Math.round(v * 100) + " %" },
    { key: "blurNoise", category: "blur", kind: "slider", label: I18n.tr("settings.blurNoise"), step: 0.005, format: v => (v * 100).toFixed(1) + " %" },
    { key: "windowBorderWidth", category: "windows", kind: "slider", same: "windowBorderSame", sameText: I18n.tr("settings.windowBorderSame"), title: I18n.tr("settings.windows.synced"), label: I18n.tr("settings.windowBorderWidth"), step: 1, format: v => v + " px" },
    { key: "windowRounding", category: "windows", kind: "slider", same: "windowRoundingSame", sameText: I18n.tr("settings.windowRoundingSame"), label: I18n.tr("settings.windowRounding"), step: 1, format: v => v + " px" },
    { key: "windowGapsIn", category: "windows", kind: "slider", same: "windowGapsInSame", sameText: I18n.tr("settings.windowGapsInSame"), label: I18n.tr("settings.windowGapsIn"), step: 1, format: v => v + " px" },
    { key: "windowGapsOut", category: "windows", kind: "slider", title: I18n.tr("settings.windows.hyprlandOnly"), label: I18n.tr("settings.windowGapsOut"), step: 1, format: v => v + " px" },
    // The windows' opacity when focused and when not, on one line like an
    // app's own (see SettingsPanel's app opacity rows); `settings` are those
    // it holds.
    { key: "windowOpacity", category: "windows", kind: "appOpacity", general: true, settings: ["windowActiveOpacity", "windowInactiveOpacity", "windowActiveOpacitySame", "windowInactiveOpacitySame"], label: I18n.tr("settings.windowOpacity") },
    { key: "blurXrayRow", category: "blur", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.blurXray"), toggles: [
      { key: "blurXray", text: "" }
    ] },
    { key: "panelGap", category: "appearance", kind: "slider", label: I18n.tr("settings.panelGap"), step: 1, format: v => v + " px" },
    { key: "curvedJoinsRow", category: "appearance", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.curvedJoins"), toggles: [
      { key: "curvedJoins", text: "" }
    ] },
    { key: "curvedJoinsRadius", category: "appearance", kind: "slider", label: I18n.tr("settings.curvedJoinsRadius"), step: 1, format: v => v + " px" },
    { key: "curvedJoinsRadiusSameRow", category: "appearance", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.curvedJoinsRadiusSame"), toggles: [
      { key: "curvedJoinsRadiusSame", text: "" }
    ] },
    { key: "animationsRow", category: "animations", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.animations"), toggles: [
      { key: "animations", text: "" }
    ] },
    { key: "animationDuration", category: "animations", kind: "slider", label: I18n.tr("settings.animationDuration"), step: 10, format: v => v + " ms" },
    { key: "hyprlandAnimationsRow", category: "hyprlandAnimations", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.hyprlandAnimations"), toggles: [
      { key: "hyprlandAnimations", text: "" }
    ] },
    { key: "hyprlandAnimationDuration", category: "hyprlandAnimations", kind: "slider", same: "hyprlandAnimationSame", sameText: I18n.tr("settings.hyprlandAnimationSame"), label: I18n.tr("settings.hyprlandAnimationDuration"), step: 0.25, format: v => "×" + v.toFixed(2) },
    { key: "hyprlandWindowStyle", category: "hyprlandAnimations", kind: "dropdown", label: I18n.tr("settings.hyprlandWindowStyle") },
    { key: "hyprlandWorkspaceStyle", category: "hyprlandAnimations", kind: "dropdown", label: I18n.tr("settings.hyprlandWorkspaceStyle") },
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
    { key: "lockStayAwakeFullscreenRow", category: "lock", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.lockStayAwakeFullscreen"), toggles: [
      { key: "lockStayAwakeFullscreen", text: "" }
    ] },
    { key: "launcherTab", category: "launcher", kind: "buttons", label: I18n.tr("settings.launcherTab") },
    { key: "launcherResults", category: "launcher", kind: "slider", label: I18n.tr("settings.launcherResults"), step: 1, format: v => String(v) },
    { key: "launcherHistory", category: "launcher", kind: "slider", label: I18n.tr("settings.launcherHistory"), step: 1, format: v => String(v) },
    { key: "panelPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.all") },
    { key: "launcherPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.launcher") },
    { key: "settingsPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.settings") },
    { key: "shortcutsPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.shortcuts") },
    { key: "wallpaperPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.wallpaper") },
    { key: "themePlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.theme") },
    { key: "powerPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.power") },
    { key: "notificationActionsPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.notificationActions") },
    { key: "switcherPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.switcher") },
    { key: "clockPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.category.clock") },
    { key: "notificationCenterPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.notificationCenter") },
    { key: "chatAiPlacement", category: "panels", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.placement.chatAi") },
    // The tools the AI may use, on or off.
    { key: "chatAiFileTools", category: "chatAiAccess", kind: "toggles", label: I18n.tr("settings.chatAiFileTools"), toggles: [
      { key: "chatAiListDir", text: I18n.tr("settings.chatAiTool.listDir") },
      { key: "chatAiFindFiles", text: I18n.tr("settings.chatAiTool.findFiles") },
      { key: "chatAiSearchText", text: I18n.tr("settings.chatAiTool.searchText") },
      { key: "chatAiReadFile", text: I18n.tr("settings.chatAiTool.readFile") }
    ] },
    { key: "chatAiWebTools", category: "chatAiAccess", kind: "toggles", label: I18n.tr("settings.chatAiWebTools"), toggles: [
      { key: "chatAiWebSearch", text: I18n.tr("settings.chatAiTool.webSearch") },
      { key: "chatAiWebFetch", text: I18n.tr("settings.chatAiTool.webFetch") }
    ] },
    { key: "chatAiShellTools", category: "chatAiAccess", kind: "toggles", label: I18n.tr("settings.chatAiShellTools"), toggles: [
      { key: "chatAiShellDocs", text: I18n.tr("settings.chatAiTool.shellDocs") },
      { key: "chatAiShellIpc", text: I18n.tr("settings.chatAiTool.shellIpc") }
    ] },
    { key: "chatAiFolders", category: "chatAiAccess", kind: "path", label: I18n.tr("settings.chatAiFolders"), placeholder: I18n.tr("settings.chatAiExclude.none") },
    { key: "chatAiExclude", category: "chatAiAccess", kind: "path", label: I18n.tr("settings.chatAiExclude"), placeholder: I18n.tr("settings.chatAiExclude.none") },
    { key: "chatAiHistory", category: "chatAiHistory", kind: "slider", stepper: true, label: I18n.tr("settings.chatAiHistory"), step: 1, format: v => String(v) },
    { key: "chatAiShowUsageRow", category: "chatAiHistory", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.chatAiShowUsage"), toggles: [
      { key: "chatAiShowUsage", text: "" }
    ] },
    { key: "chatAiShowHintRow", category: "chatAiHistory", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.chatAiShowHint"), toggles: [
      { key: "chatAiShowHint", text: "" }
    ] },
    { key: "chatAiShowAccessRow", category: "chatAiHistory", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.chatAiShowAccess"), toggles: [
      { key: "chatAiShowAccess", text: "" }
    ] },
    { key: "switcherOrientation", category: "switcher", kind: "buttons", label: I18n.tr("settings.switcherOrientation") },
    { key: "switcherScope", category: "switcher", kind: "buttons", label: I18n.tr("settings.switcherScope") },
    { key: "switcherGroupAppsRow", category: "switcher", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.switcherGroupApps"), toggles: [
      { key: "switcherGroupApps", text: "" }
    ] },
    { key: "switcherTextRow", category: "switcher", kind: "toggles", label: I18n.tr("settings.switcherText"), toggles: [
      { key: "switcherShowTitle", text: I18n.tr("settings.switcherText.title") },
      { key: "switcherShowApp", text: I18n.tr("settings.switcherText.app") },
      { key: "switcherShowWorkspace", text: I18n.tr("settings.switcherText.workspace") }
    ] },
    { key: "switcherIconSize", category: "switcher", kind: "slider", label: I18n.tr("settings.switcherIconSize"), step: 4, format: v => v + " px" },
    { key: "switcherMaxShown", category: "switcher", kind: "slider", label: I18n.tr("settings.switcherMaxShown"), step: 1, format: v => String(v) },
    { key: "switcherReleaseSwitchRow", category: "switcher", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.switcherReleaseSwitch"), toggles: [
      { key: "switcherReleaseSwitch", text: "" }
    ] },
    { key: "clockTabsRow", category: "clockPanel", kind: "toggles", label: I18n.tr("settings.clockTabs"), toggles: [
      { key: "clockShowAgenda", text: I18n.tr("clock.tab.agenda") },
      { key: "clockShowPerformance", text: I18n.tr("clock.tab.performance") },
      { key: "clockShowMedia", text: I18n.tr("clock.tab.media") },
      { key: "clockShowWeather", text: I18n.tr("clock.tab.weather") },
      { key: "clockShowWorld", text: I18n.tr("clock.tab.world") }
    ] },
    { key: "weatherUnit", category: "clockPanel", kind: "buttons", title: I18n.tr("clock.tab.weather"), label: I18n.tr("settings.weatherUnit") },
    { key: "webAppCommand", category: "webApps", kind: "path", label: I18n.tr("settings.webAppCommand") },
    { key: "weatherLocation", category: "clockPanel", kind: "path", label: I18n.tr("settings.weatherLocation"), placeholder: I18n.tr("settings.weatherLocation.auto") },
    { key: "switcherPreviewsRow", category: "switcher", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.switcherPreviews"), toggles: [
      { key: "switcherPreviews", text: "" }
    ] },
    { key: "sideLookRow", category: "widgetSettings", kind: "toggles", title: I18n.tr("settings.sideLook"), label: I18n.tr("settings.sideLook.label"), toggles: [
      { key: "cpuRing", text: I18n.tr("settings.widget.cpu") },
      { key: "ramRing", text: I18n.tr("settings.widget.ram") },
      { key: "diskRing", text: I18n.tr("settings.widget.disk") },
      { key: "volumeRing", text: I18n.tr("settings.widget.volume") },
      { key: "networkRing", text: I18n.tr("settings.widget.network") },
      { key: "activeWindowIconOnly", text: I18n.tr("settings.widget.activeWindow") }
    ] },
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
      for (const key of row.settings ?? []) keys.push(key)
      // A slider's SameButton sets one of its own.
      if (row.same) keys.push(row.same)
    }
    // The launcher's engines have a row each, none named after the setting.
    if (categoryId === "launcher") keys.push("launcherEngines")
    // Nor do the web apps.
    if (categoryId === "webApps") keys.push("webApps")
    // Nor do the chat AI's providers.
    if (categoryId === "chatAi") keys.push("chatAiProviders", "chatAiDefaultProvider")
    // Nor do the clocks tab's places.
    if (categoryId === "clockPanel") keys.push("worldClocks")
    // Nor do the theme's added apps.
    if (categoryId === "theme") keys.push("matugenApps")
    // Nor do the App opacity tab's app opacities.
    if (categoryId === "appOpacity") keys.push("appOpacities")
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
