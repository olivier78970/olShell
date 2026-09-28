import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Settings panel, toggled from outside via:
//   quickshell -p . ipc call settings toggle
// Each setting applies as soon as it's changed and is remembered (see
// Settings.qml; the language by I18n). Click or drag a slider, or use the
// keys: Up/Down select a row, Left/Right adjust it (Shift for bigger steps),
// PageUp/PageDown switch category, Tab/Shift+Tab switch tab on a category
// that has tabs, Escape closes. Enter opens the list of a
// dropdown row (Up/Down then move in it, Enter picks, Escape closes just the
// list); on the font style row, Left/Right move between the buttons and Enter
// switches one. The rows are grouped in categories, chosen with the icons on the left.
ModalPanel {
  id: root

  // The categories and their pages (see SettingsPages).
  readonly property var categories: SettingsPages.categories
  readonly property var pages: SettingsPages.pages

  // The tabs of the current category ([] for none), the one showing, and the
  // page they make current.
  readonly property var tabs: root.categories[root.category].tabs ?? []
  property int tab: SettingsPanelState.tab
  onTabChanged: SettingsPanelState.tab = root.tab
  readonly property string page: root.tabs.length > 0 ? root.tabs[root.tab].id : root.categories[root.category].id

  // The rows of every category, top to bottom: the ones holding a setting
  // (see SettingsPages), then the launcher's engines, the theme's added apps
  // and each page's defaults row.
  readonly property var allRows: SettingsPages.rows.concat(root.engineRows).concat(root.matugenAppRows).concat(root.defaultRows)

  // The last row of every page: its defaults (see DefaultsRow).
  readonly property var defaultRows: root.pages.map(page => ({
    key: "defaults:" + page, category: page, kind: "defaults", label: I18n.tr("settings.defaults")
  }))

  // The launcher category's search engines, a row each in their order (the
  // first with the list's title above it), then a row adding one. A row's
  // `engineIndex` is its engine's place in Settings.launcherEngines.
  readonly property var engineRows: Settings.launcherEngines.map((engine, index) => ({
    key: "engine:" + index,
    category: "launcher",
    kind: "engine",
    engine: engine,
    engineIndex: index,
    label: !engine.browser ? engine.name
      : WebSearch.browserEngine ? I18n.tr("settings.launcherEngines.browser", WebSearch.browserEngine.name)
      : I18n.tr("settings.launcherEngines.browserUnknown", Apps.webSearchFallback.name),
    title: index === 0 ? I18n.tr("settings.launcherEngines") : "",
    canMoveBack: index > 0,
    canMoveForward: index < Settings.launcherEngines.length - 1
  })).concat([{ key: "addEngine", category: "launcher", kind: "action", label: I18n.tr("settings.launcherEngines.add") }])

  // The theme category's added apps (after the other apps' row), a row each,
  // and the row adding one. `appIndex` is its app's place in
  // Settings.matugenApps.
  readonly property var matugenAppRows: Settings.matugenApps.map((app, index) => ({
    key: "matugenApp:" + index,
    category: "theme",
    kind: "matugenApp",
    app: app,
    appIndex: index
  })).concat([{ key: "addMatugenApp", category: "theme", kind: "action", label: I18n.tr("settings.matugenApps.add") }])

  // The fields of an added app's row, by its focusIndex (see ThemeAppRow).
  readonly property var matugenAppFields: ["", "name", "template", "output", "hook"]

  // What the keys do on an added app's row, on what they are on: switch it
  // on or off, type in one of its fields, or remove it.
  function pressMatugenApp(row, index) {
    if (index === 0) Settings.setMatugenApp(row.appIndex, { on: !row.app.on })
    else if (index >= 1 && index <= 4) root.editKey = row.key + ":" + root.matugenAppFields[index]
    else if (index === 5) Settings.removeMatugenApp(row.appIndex)
  }

  // Adds an app, selects its row and starts typing its name.
  function addMatugenApp() {
    Settings.addMatugenApp(I18n.tr("settings.matugenApps.new"))
    const key = "matugenApp:" + (Settings.matugenApps.length - 1)
    Qt.callLater(() => {
      const index = root.rows.findIndex(row => row.key === key)
      if (index < 0) return
      root.selected = index
      root.toggleFocus = 1
      root.editKey = key + ":name"
    })
  }

  // What the keys do on an engine row, on what they are on (see
  // SearchEngineRow's focusIndex): switch it on or off, type in its name or
  // address, or remove it.
  function pressEngine(row, index) {
    if (index === 0) Settings.setEngine(row.engineIndex, { on: !row.engine.on })
    else if (index === 1) root.editKey = row.key + ":name"
    else if (index === 2) root.editKey = row.key + ":url"
    else if (index === 3) Settings.removeEngine(row.engineIndex)
  }

  // Moves the engine of `row` `steps` places, the selection going with it.
  function moveEngine(row, steps) {
    const target = Math.max(0, Math.min(Settings.launcherEngines.length - 1, row.engineIndex + steps))
    root.selectedKey = "engine:" + target
    Settings.moveEngine(row.engineIndex, steps)
  }

  // Adds a search engine with a name and an address to be replaced, selects
  // its row and starts typing its name.
  function addEngine() {
    if (!Settings.addEngine(I18n.tr("settings.launcherEngines.new"), "https://example.com/search?q=%s")) return
    const key = "engine:" + (Settings.launcherEngines.length - 1)
    Qt.callLater(() => {
      const index = root.rows.findIndex(row => row.key === key)
      if (index < 0) return
      root.selected = index
      root.toggleFocus = 1
      root.editKey = key + ":name"
    })
  }

  // The pop-up positions, named in the current language.
  readonly property var positionOptions: Settings.choices.notificationPosition
    .map(name => ({ value: name, text: I18n.tr("settings.position." + name) }))

  // The OSD positions, named in the current language.
  readonly property var osdPositionOptions: Settings.osdPositions
    .map(name => ({ value: name, text: I18n.tr("settings.position." + name) }))

  // The wallpaper transitions, named in the current language.
  readonly property var transitionOptions: Settings.choices.wallpaperTransition
    .map(name => ({ value: name, text: I18n.tr("settings.transition." + name) }))

  // The choices of the theme rows (mode, widget background, and the
  // "Automatique" palette style, starting color and accent), named in the
  // current language; the accents show their color from the current palette.
  readonly property var matugenOptions: ({
    themeMode: Settings.choices.themeMode.map(name => ({ value: name, text: I18n.tr("settings.themeMode." + name) })),
    matugenScheme: Settings.choices.matugenScheme.map(name => ({ value: name, text: I18n.tr("settings.matugenScheme." + name) })),
    matugenSource: Settings.choices.matugenSource.map(name => ({ value: name, text: I18n.tr("settings.matugenSource." + name) })),
    matugenAccent: Settings.choices.matugenAccent.map(name => ({ value: name, text: I18n.tr("settings.matugenAccent." + name), swatch: GeneratedColors.matugenAccents[name] })),
    themePill: Settings.choices.themePill.map(name => ({ value: name, text: I18n.tr("settings.themePill." + name) }))
  })

  // The rows that only apply to the "Automatique" theme.
  readonly property var matugenAutoRows: ["matugenScheme", "matugenSource", "matugenContrast", "matugenLightness", "matugenAccent"]

  // The fixed theme's accents, as color dots, after its own default one
  // (none but the default while another kind of theme is used), and the
  // one of them in use: the default for a color the theme doesn't have.
  readonly property var themeAccentOptions: [{ value: "default", text: I18n.tr("settings.themeAccent.default") }]
    .concat(ThemePresets.accentNames
      .filter(name => ThemeState.active.accents?.[name] !== undefined)
      .map(name => ({ value: name, text: "", swatch: ThemeState.active.accents[name] })))
  readonly property string themeAccentCurrent: root.themeAccentOptions.some(option => option.value === Settings.themeAccent) ? Settings.themeAccent : "default"

  // The value a buttons or dropdown row shows as current.
  function currentOf(row) {
    if (row.key === "themeAccent") return root.themeAccentCurrent
    return Settings.get(row.key)
  }

  // The Nerd Font families installed (the shell's icons are Nerd Font glyphs),
  // plus the current one if it isn't among them, e.g. set by hand. Any other
  // installed family can be set with `ipc call settings choose fontFamily`.
  // Qt only looks at the installed fonts when the shell starts, so a font
  // installed or removed since needs a restart. Made when the panel opens
  // rather than bound to the current font: picking a font must not change the
  // list under the pointer.
  property var fontOptions: []

  function refreshFontOptions() {
    const names = Qt.fontFamilies().filter(name => name.includes("Nerd Font"))
    if (!names.includes(Settings.fontFamily)) names.push(Settings.fontFamily)
    root.fontOptions = names.sort().map(name => ({ value: name, text: name }))
  }

  // Which buttons of a toggle row are on, by setting key.
  function checkedOf(row) {
    const checked = {}
    for (const toggle of row.toggles ?? []) checked[toggle.key] = Settings.get(toggle.key) === true
    return checked
  }

  // The button of the selected toggle row the keys are on.
  property int toggleFocus: 0

  // The capitalizations, named in the current language.
  readonly property var capsOptions: Settings.choices.fontCaps
    .map(name => ({
      value: name,
      text: I18n.tr("settings.caps." + name),
      capitalization: name === "small" ? Font.SmallCaps : Font.MixedCase
    }))

  // An "action" row's button: what it says, and what it does.
  function actionButtonText(row) {
    if (row.key === "notificationActions") return I18n.tr("settings.notificationActions.manage", NotificationActions.rules.length)
    if (row.key === "addEngine") return I18n.tr("settings.launcherEngines.addButton")
    if (row.key === "customCopy") return I18n.tr("settings.custom.copyButton")
    if (row.key === "addMatugenApp") return I18n.tr("settings.launcherEngines.addButton")
    return ""
  }

  function runAction(row) {
    if (row.key === "notificationActions") NotificationActionsState.open(true)
    if (row.key === "addEngine") root.addEngine()
    if (row.key === "customCopy") root.copyToCustom()
    if (row.key === "addMatugenApp") root.addMatugenApp()
  }

  // Makes the custom theme's colors those of the theme in use (without its
  // widget background level, which the custom theme applies too).
  function copyToCustom() {
    const colors = ThemeState.active.baseColors ?? GeneratedColors.matugenBaseColors
    Settings.set("customBackground", String(colors.backgroundColor))
    Settings.set("customPill", String(colors.pillColor))
    Settings.set("customBorder", String(colors.borderColor))
    Settings.set("customText", String(colors.textColor))
    Settings.set("customAccent", String(colors.accentColor))
  }

  // Whether row `row` can be adjusted right now.
  function rowEnabled(row) {
    if (row.key === "barAutoHideAnimatedRow") return Theme.barAutoHide
    if (row.key === "barAutoHideDuration") return Theme.barAutoHide && Theme.barAutoHideAnimated
    if (row.key === "borderOpaqueRow") return Theme.borderWidth > 0
    if (row.key === "curvedJoinsRow") return Theme.panelGap <= 0 && Theme.borderWidth === 0
    // Hyprland's blur options only matter while the blur is on.
    if (root.blurRows.includes(row.key)) return Settings.blur
    // A window value following the shell's has nothing of its own to set.
    if (row.key === "windowBorderWidth") return !Settings.windowBorderSame
    if (row.key === "windowRounding") return !Settings.windowRoundingSame
    if (row.key === "windowGapsIn") return !Settings.windowGapsInSame
    if (row.key === "curvedJoinsRadiusSameRow") return Theme.panelGap <= 0 && Theme.curvedJoins
    if (row.key === "curvedJoinsRadius") return Theme.panelGap <= 0 && Theme.curvedJoins && !Settings.curvedJoinsRadiusSame
    if (row.key === "workspaceCount") return !Settings.workspaceCountFromHyprland
    // Only the app switcher's cards have room for a window's picture.
    if (row.key === "switcherPreviewsRow") return Settings.switcherOrientation === "horizontal"
    // An OSD in the center of the screen touches no edge.
    if (row.key === "volumeOsdMargin") return Settings.volumeOsdPosition !== "center-center"
    if (row.key === "lockKeysOsdMargin") return Settings.lockKeysOsdPosition !== "center-center"
    // A fixed theme doesn't take its colors from the wallpaper.
    if (root.matugenAutoRows.includes(row.key)) return ThemeState.active.kind === "auto"
    // Only the "Automatique" theme and the fixed ones with a light version
    // can be light or dark.
    if (row.key === "themeMode") return ThemeState.active.hasLight
    if (row.key === "themeAccent") return ThemeState.active.kind === "fixed"
    if (row.key === "themeExactAppsRow") return ThemeState.active.kind !== "auto"
    return true
  }

  // What slider `row` shows: its setting's value, or for the workspace
  // count while it follows the Hyprland config, the count the bar shows, and
  // for the curves' radius while it follows the widgets', theirs.
  function sliderValueOf(row) {
    if (row.key === "workspaceCount") return WorkspaceRules.shownCount
    if (row.key === "curvedJoinsRadius") return Theme.joinRadius
    if (row.key === "windowBorderWidth") return HyprlandWindows.borderSize
    if (row.key === "windowRounding") return HyprlandWindows.rounding
    if (row.key === "windowGapsIn") return HyprlandWindows.gapsIn
    return Settings.get(row.key)
  }

  // The rows of Hyprland's blur options (see rowEnabled()).
  readonly property var blurRows: ["blurSize", "blurPasses", "blurVibrancy", "blurContrast", "blurBrightness", "blurNoise", "blurXrayRow"]

  // Why `row` is disabled right now, for its tooltip; "" when it isn't.
  function disabledReasonOf(row) {
    if (root.blurRows.includes(row.key) && !Settings.blur) return I18n.tr("settings.blur.disabledOff")
    if (row.key === "windowBorderWidth" && Settings.windowBorderSame) return I18n.tr("settings.windowBorderSame.disabled")
    if (row.key === "windowRounding" && Settings.windowRoundingSame) return I18n.tr("settings.windowRoundingSame.disabled")
    if (row.key === "windowGapsIn" && Settings.windowGapsInSame) return I18n.tr("settings.windowGapsInSame.disabled")
    if (row.key === "barAutoHideAnimatedRow" && !Theme.barAutoHide) return I18n.tr("settings.barAutoHide.disabledOff")
    if (row.key === "barAutoHideDuration" && !Theme.barAutoHide) return I18n.tr("settings.barAutoHide.disabledOff")
    if (row.key === "barAutoHideDuration" && !Theme.barAutoHideAnimated) return I18n.tr("settings.barAutoHideDuration.disabled")
    if (row.key === "borderOpaqueRow" && Theme.borderWidth === 0) return I18n.tr("settings.borderOpaque.disabledNone")
    if (row.key === "workspaceCount" && Settings.workspaceCountFromHyprland) return I18n.tr("settings.workspaceCount.disabledHyprland")
    if (row.key === "curvedJoinsRow" && Theme.panelGap > 0) return I18n.tr("settings.curvedJoins.disabledGap")
    if ((row.key === "curvedJoinsRadius" || row.key === "curvedJoinsRadiusSameRow") && Theme.panelGap > 0) return I18n.tr("settings.curvedJoins.disabledGap")
    if ((row.key === "curvedJoinsRow" || row.key === "curvedJoinsRadius" || row.key === "curvedJoinsRadiusSameRow") && Theme.borderWidth > 0) return I18n.tr("settings.curvedJoins.disabledBorder")
    if ((row.key === "curvedJoinsRadius" || row.key === "curvedJoinsRadiusSameRow") && !Theme.curvedJoins) return I18n.tr("settings.curvedJoinsRadius.disabledOff")
    if (row.key === "curvedJoinsRadius" && Settings.curvedJoinsRadiusSame) return I18n.tr("settings.curvedJoinsRadius.disabledSame")
    if (row.key === "switcherPreviewsRow" && Settings.switcherOrientation !== "horizontal") return I18n.tr("settings.switcherPreviews.disabled")
    if (row.key === "volumeOsdMargin" && Settings.volumeOsdPosition === "center-center") return I18n.tr("settings.osdMargin.disabledCenter")
    if (row.key === "lockKeysOsdMargin" && Settings.lockKeysOsdPosition === "center-center") return I18n.tr("settings.osdMargin.disabledCenter")
    if (root.matugenAutoRows.includes(row.key) && ThemeState.active.kind !== "auto") return I18n.tr("settings.matugen.disabledFixed")
    if (row.key === "themeMode" && ThemeState.active.kind === "custom") return I18n.tr("settings.themeMode.disabledCustom")
    if (row.key === "themeMode" && !ThemeState.active.hasLight) return I18n.tr("settings.themeMode.disabledNoLight")
    if (row.key === "themeAccent" && ThemeState.active.kind !== "fixed") return I18n.tr("settings.themeAccent.disabled")
    if (row.key === "themeExactAppsRow" && ThemeState.active.kind === "auto") return I18n.tr("settings.themeExactApps.disabled")
    return ""
  }

  // The options of a buttons or dropdown row.
  function optionsOf(row) {
    if (row.key === "fontFamily") return root.fontOptions
    if (row.key === "fontCaps") return root.capsOptions
    if (row.key === "wallpaperTransition") return root.transitionOptions
    if (root.matugenOptions[row.key] !== undefined) return root.matugenOptions[row.key]
    if (row.key === "themeAccent") return root.themeAccentOptions
    if (row.key === "notificationPosition") return root.positionOptions
    if (row.key === "volumeOsdPosition" || row.key === "lockKeysOsdPosition") return root.osdPositionOptions
    if (row.key === "barStyle") return root.barStyleOptions
    if (row.key === "barPosition") return root.barPositionOptions
    if (row.key === "launcherTab") return root.launcherTabOptions
    if (row.key === "clockDate") return root.clockDateOptions
    if (row.key === "switcherOrientation") return root.switcherOrientationOptions
    if (row.key === "switcherScope") return root.switcherScopeOptions
    if (row.key === "weatherUnit") return root.weatherUnitOptions
    if (Settings.choices[row.key] === Settings.panelPlacements) return root.placementOptions
    if (row.key === "panelPlacement") return root.allPlacementOptions
    return []
  }

  // Whether the bar has one background behind all its widgets ("full") or
  // each widget pill has its own ("widgets"), named in the current language.
  readonly property var barStyleOptions: Settings.choices.barStyle
    .map(name => ({ value: name, text: I18n.tr("settings.barStyle." + name) }))

  // Which edge of the screen the bar is on, named in the current language.
  readonly property var barPositionOptions: Settings.choices.barPosition
    .map(name => ({ value: name, text: I18n.tr("settings.barPosition." + name) }))

  // Where a panel can open, named in the current language.
  readonly property var placementOptions: Settings.panelPlacements
    .map(name => ({ value: name, text: I18n.tr("settings.placement." + name) }))

  // The same for every panel at once, and "each" for when they differ.
  readonly property var allPlacementOptions: Settings.choices.panelPlacement
    .map(name => ({ value: name, text: I18n.tr("settings.placement." + name) }))

  // The app switcher's directions, named in the current language.
  readonly property var switcherOrientationOptions: Settings.choices.switcherOrientation
    .map(name => ({ value: name, text: I18n.tr("settings.switcherOrientation." + name) }))

  // Which windows the app switcher lists, named in the current language.
  readonly property var switcherScopeOptions: Settings.choices.switcherScope
    .map(name => ({ value: name, text: I18n.tr("settings.switcherScope." + name) }))

  // The weather's temperature units, named in the current language.
  readonly property var weatherUnitOptions: Settings.choices.weatherUnit
    .map(name => ({ value: name, text: I18n.tr("settings.weatherUnit." + name) }))

  // The launcher's tabs, named as in the launcher.
  readonly property var launcherTabOptions: Settings.choices.launcherTab
    .map(name => ({ value: name, text: I18n.tr("launcher.tab." + name) }))

  // The bar clock's date formats, each shown as today's date written that
  // way in the current language.
  readonly property var clockDateOptions: Settings.choices.clockDate
    .map(name => ({ value: name, text: name === "none" ? I18n.tr("settings.clockDate.none") : new Date().toLocaleDateString(I18n.locale, I18n.value("format.date." + name)) }))

  // Language choices: follow the system, or one of the supported languages.
  readonly property var languageOptions: [{ value: "auto", text: I18n.tr("settings.language.auto") }]
    .concat(I18n.supported.map(code => ({ value: code, text: I18n.languageNames[code] })))

  // The category shown, kept in SettingsPanelState between openings.
  property int category: SettingsPanelState.category
  onCategoryChanged: SettingsPanelState.category = root.category
  // The rows of the current page; `selected` indexes into these.
  readonly property var rows: root.allRows.filter(row => row.category === root.page)
  property int selected: 0
  // The width the panel needs for the rows of the current category: the widest
  // row, and what surrounds them (the category rail, its divider, the margins
  // and the room for the scroll bar).
  readonly property real neededWidth: {
    let need = 0
    for (let i = 0; i < rowsRepeater.count; i++) need = Math.max(need, rowsRepeater.itemAt(i)?.need ?? 0)
    return rail.width + 79 + need
  }
  // The key of the selected row, so the selection follows a row that moves
  // (a widget put in another section is listed elsewhere).
  property string selectedKey: ""

  function syncSelectedKey() {
    root.selectedKey = root.rows[root.selected]?.key ?? ""
  }

  onRowsChanged: {
    const index = root.rows.findIndex(row => row.key === root.selectedKey)
    if (index >= 0 && index !== root.selected) root.selected = index
    else root.syncSelectedKey()
  }
  // The row whose list of options is showing (its key, "" for none), and the
  // entry of that list the keys are on.
  property string openKey: ""
  property int highlight: 0
  // The row being typed into (its key, "" for none): a text field has the
  // keyboard then, and the panel's own keys are off.
  property string editKey: ""

  // Wide enough for the widest row of the category: the names are longer in
  // some languages (French), and so is what they share a row with. Never
  // narrower than the usual size.
  maxPanelWidth: Math.max(920, root.neededWidth)
  placement: Settings.settingsPlacement
  // Tall enough for the whole page (its title, tabs and rows, with the
  // margins around them, and the keys hint under them), never shorter than
  // the usual size; the screen still caps it (see ModalPanel), the rows
  // scrolling past that.
  readonly property real neededHeight: 20 + titleRow.height + 10 + (tabBar.visible ? tabBar.height + 10 : 0) + rowsColumn.height + 10 + hint.height + 20
  maxPanelHeight: Math.max(780, root.neededHeight)

  open: SettingsPanelState.visible
  // Escape closes an open list first, then the panel.
  onCloseRequested: {
    if (root.confirmAll) root.confirmAll = false
    else if (root.confirmKey !== "") root.confirmKey = ""
    else if (root.editKey !== "") root.editKey = ""
    else if (root.openKey !== "") root.openKey = ""
    else SettingsPanelState.visible = false
  }
  onOpened: {
    if (SettingsPanelState.resuming) {
      SettingsPanelState.resuming = false
      return
    }
    root.selected = 0
    root.openKey = ""
    root.refreshFontOptions()
    // For the browser's engine row, in case it changed.
    WebSearch.refresh()
  }
  onSelectedChanged: {
    root.syncSelectedKey()
    root.openKey = ""
    root.editKey = ""
    root.confirmKey = ""
    root.confirmAll = false
    root.toggleFocus = 0
  }

  // Whether the factory reset of everything (the general category's row) waits
  // for its confirmation.
  property bool confirmAll: false

  // The button of the "all categories" row: Factory defaults, which asks; or,
  // while asking, Confirm (0) and Cancel (1).
  function pressFactoryAll(index) {
    if (!root.confirmAll) {
      root.confirmAll = true
      // On Cancel, the safe answer.
      root.toggleFocus = 1
    } else {
      if (index === 0) SettingsPages.factoryResetAll()
      root.confirmAll = false
    }
  }

  // The category whose factory reset is waiting for a confirmation ("" for none):
  // its defaults row then asks, with Confirm and Cancel instead of its buttons.
  property string confirmKey: ""

  // The buttons of the defaults row, in the order of DefaultsRow's `pressed`:
  // save, factory (which asks first); or, while asking, confirm and cancel.
  function pressDefaults(categoryId, index) {
    if (root.confirmKey === categoryId) {
      // Back to the built-in values, which then are the user's defaults too.
      if (index === 0) {
        SettingsPages.restoreDefaults(categoryId, "factory")
        SettingsPages.saveDefaults(categoryId)
      }
      root.confirmKey = ""
    } else if (index === 0) {
      SettingsPages.saveDefaults(categoryId)
    } else {
      root.confirmKey = categoryId
      // On Cancel, the safe answer.
      root.toggleFocus = 1
    }
  }

  function selectCategory(index) {
    root.openKey = ""
    root.editKey = ""
    root.confirmKey = ""
    root.confirmAll = false
    root.category = Math.max(0, Math.min(root.categories.length - 1, index))
    root.selectTab(0)
  }

  // Shows tab `index` of the current category, wrapping around at both ends.
  function selectTab(index) {
    root.openKey = ""
    root.editKey = ""
    root.confirmKey = ""
    root.confirmAll = false
    root.tab = root.tabs.length > 0 ? (index + root.tabs.length) % root.tabs.length : 0
    // A click sets the tab bar's own index (no longer bound): keep it right.
    tabBar.currentIndex = root.tab
    root.selected = 0
  }

  // Moves the selected row's value one step (or `steps` of them) up or down.
  function adjust(direction, steps) {
    const row = root.rows[root.selected]
    if (!root.rowEnabled(row)) return
    if (row.kind === "slider") {
      Settings.set(row.key, Settings.get(row.key) + direction * row.step * steps)
    } else if (row.kind === "dropdown" || row.kind === "buttons") {
      const values = root.optionsOf(row).map(option => option.value)
      const next = ((values.indexOf(root.currentOf(row)) + direction * steps) % values.length + values.length) % values.length
      Settings.set(row.key, values[next])
    } else if (row.kind === "choice") {
      const values = root.languageOptions.map(option => option.value)
      const next = (values.indexOf(I18n.setting) + direction + values.length) % values.length
      I18n.select(values[next])
    }
  }

  // Opens (or closes) the list of a dropdown row, on the current value.
  function toggleDropdown(row) {
    if (root.openKey === row.key) {
      root.openKey = ""
      return
    }
    const values = root.optionsOf(row).map(option => option.value)
    root.highlight = Math.max(0, values.indexOf(Settings.get(row.key)))
    root.openKey = row.key
  }

  // Keys while a list is open: they move in it, pick from it, or (Escape)
  // just close it, without closing the panel itself.
  function listKeyPressed(event) {
    const row = root.rows.find(candidate => candidate.key === root.openKey)
    const options = root.optionsOf(row)
    const last = options.length - 1
    if (event.key === Qt.Key_Down) root.highlight = Math.min(last, root.highlight + 1)
    else if (event.key === Qt.Key_Up) root.highlight = Math.max(0, root.highlight - 1)
    else if (event.key === Qt.Key_PageDown) root.highlight = Math.min(last, root.highlight + 8)
    else if (event.key === Qt.Key_PageUp) root.highlight = Math.max(0, root.highlight - 8)
    else if (event.key === Qt.Key_Home) root.highlight = 0
    else if (event.key === Qt.Key_End) root.highlight = last
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      // Close first: applying it may rebuild what the list belongs to.
      root.openKey = ""
      Settings.set(row.key, options[root.highlight].value)
    } else if (event.key === Qt.Key_Escape) {
      root.openKey = ""
    }
    event.accepted = true
  }

  onKeyPressed: event => {
    // While typing in a text field, its keys are its own (it took the ones
    // it uses; the rest, like Page Up, are not the panel's).
    if (root.editKey !== "") {
      event.accepted = true
      return
    }
    if (root.openKey !== "") {
      root.listKeyPressed(event)
      return
    }
    const big = (event.modifiers & Qt.ShiftModifier) !== 0
    const kind = root.rows[root.selected].kind
    if ((kind === "path" || (kind === "slider" && root.rows[root.selected].stepper)) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      // Enter: type in the field (a path's, or a stepper's value).
      root.editKey = root.rows[root.selected].key
      event.accepted = true
    } else if (kind === "engine" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Left / Right: what the keys are on (check box, name, address,
      // remove); with Shift: the engine earlier / later in the list.
      const row = root.rows[root.selected]
      const direction = event.key === Qt.Key_Left ? -1 : 1
      if (big) root.moveEngine(row, direction)
      else root.toggleFocus = Math.max(0, Math.min(row.engine.browser ? 0 : 3, root.toggleFocus + direction))
      event.accepted = true
    } else if (kind === "matugenApp" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Left / Right: what the keys are on (check box, the fields, remove).
      root.toggleFocus = Math.max(0, Math.min(5, root.toggleFocus + (event.key === Qt.Key_Left ? -1 : 1)))
      event.accepted = true
    } else if (kind === "matugenApp" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      root.pressMatugenApp(root.rows[root.selected], root.toggleFocus)
      event.accepted = true
    } else if (kind === "engine" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      root.pressEngine(root.rows[root.selected], root.toggleFocus)
      event.accepted = true
    } else if (kind === "factoryAll" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Move between Confirm and Cancel, while asking.
      root.toggleFocus = Math.max(0, Math.min(root.confirmAll ? 1 : 0, root.toggleFocus + (event.key === Qt.Key_Left ? -1 : 1)))
      event.accepted = true
    } else if (kind === "action" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      root.runAction(root.rows[root.selected])
      event.accepted = true
    } else if (kind === "factoryAll" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      root.pressFactoryAll(root.toggleFocus)
      event.accepted = true
    } else if (kind === "defaults" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Move between the buttons of the row.
      root.toggleFocus = Math.max(0, Math.min(1, root.toggleFocus + (event.key === Qt.Key_Left ? -1 : 1)))
      event.accepted = true
    } else if (kind === "defaults" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      root.pressDefaults(root.rows[root.selected].category, root.toggleFocus)
      event.accepted = true
    } else if (kind === "toggles" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Move between the buttons of the row.
      const last = root.rows[root.selected].toggles.length - 1
      root.toggleFocus = Math.max(0, Math.min(last, root.toggleFocus + (event.key === Qt.Key_Left ? -1 : 1)))
      event.accepted = true
    } else if (kind === "slider" && root.rows[root.selected].same && event.key === Qt.Key_Space) {
      // Space: the slider's SameButton (follow the shell's value, or not).
      const key = root.rows[root.selected].same
      Settings.set(key, !Settings.get(key))
      event.accepted = true
    } else if (kind === "toggles" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      if (root.rowEnabled(root.rows[root.selected])) {
        const key = root.rows[root.selected].toggles[root.toggleFocus].key
        Settings.set(key, !Settings.get(key))
      }
      event.accepted = true
    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
        && root.rows[root.selected].kind === "dropdown") {
      root.toggleDropdown(root.rows[root.selected])
      event.accepted = true
    } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && root.tabs.length > 0) {
      // Tab / Shift+Tab: the next / previous tab, on a category that has them.
      root.selectTab(root.tab + (event.key === Qt.Key_Backtab || big ? -1 : 1))
      event.accepted = true
    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
      root.selected = Math.min(root.rows.length - 1, root.selected + 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
      root.selected = Math.max(0, root.selected - 1)
      event.accepted = true
    } else if (event.key === Qt.Key_PageDown) {
      root.selectCategory(root.category + 1)
      event.accepted = true
    } else if (event.key === Qt.Key_PageUp) {
      root.selectCategory(root.category - 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Left) {
      root.adjust(-1, big ? 5 : 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Right) {
      root.adjust(1, big ? 5 : 1)
      event.accepted = true
    }
  }

  // Not shown: the category names, only to find the widest one (in the
  // current font and language) so every rail button can be that wide.
  Column {
    id: railLabels
    opacity: 0

    Repeater {
      model: root.categories

      ThemedText {
        required property var modelData
        text: modelData.label
      }
    }
  }

  // The column of controls: past the longest label of these kinds of rows
  // (and of the steppers) on the current page. Text fields and steppers
  // start in it; check boxes, buttons and lists stay against the right edge,
  // but the page is as wide as if they started in it too. A slider is under
  // its label, so it doesn't count. Not shown: the labels, only to measure
  // them in the current font and language.
  readonly property var alignedKinds: ["toggles", "path", "dropdown", "buttons", "choice"]
  // The space between the longest label and the column.
  readonly property real labelGap: 32
  readonly property real controlX: 12 + rowLabels.implicitWidth + root.labelGap

  Column {
    id: rowLabels
    opacity: 0

    Repeater {
      model: root.rows.filter(row => root.alignedKinds.includes(row.kind) || (row.kind === "slider" && row.stepper))

      ThemedText {
        required property var modelData
        text: modelData.label
      }
    }
  }

  // Every value a slider (not a stepper) of any category can show: its
  // steps, up to a hundred of them evenly spread, and both ends.
  readonly property var sliderValueTexts: {
    const texts = new Set()
    for (const row of root.allRows) {
      if (row.kind !== "slider" || row.stepper) continue
      const [from, to] = Settings.limits[row.key]
      const count = Math.round((to - from) / row.step)
      const every = Math.max(1, Math.ceil(count / 100))
      for (let i = 0; i <= count; i += every) texts.add(row.format(Math.round((from + i * row.step) * 1000) / 1000))
      texts.add(row.format(to))
    }
    return Array.from(texts)
  }

  // Not shown: those values, to give every slider's value the width of the
  // widest, in the current font and language.
  Column {
    id: sliderValues
    opacity: 0

    Repeater {
      model: root.sliderValueTexts

      ThemedText {
        required property string modelData
        text: modelData
      }
    }
  }

  // Category buttons, one per category: an icon and the name.
  Column {
    id: rail
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.leftMargin: 14
    anchors.topMargin: 20
    spacing: 6

    Repeater {
      model: root.categories

      Item {
        id: categoryButton

        required property var modelData
        required property int index
        readonly property bool current: categoryButton.index === root.category

        width: 44 + railLabels.implicitWidth + 14
        height: 44

        Rectangle {
          anchors.fill: parent
          radius: Theme.radiusFor(height)
          color: categoryButton.current
            ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14)
            : (categoryMouse.containsMouse ? Theme.borderColor : "transparent")
          border.color: categoryButton.current ? Theme.accentColor : "transparent"
          border.width: 1
        }

        // The icon, centered in the first 44 pixels.
        ThemedText {
          width: 44
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
          text: categoryButton.modelData.icon
          sizeScale: 1.4
          color: categoryButton.current || categoryMouse.containsMouse ? Theme.accentColor : Theme.textColor
        }

        ThemedText {
          anchors.left: parent.left
          anchors.leftMargin: 44
          anchors.verticalCenter: parent.verticalCenter
          text: categoryButton.modelData.label
          color: categoryButton.current || categoryMouse.containsMouse ? Theme.accentColor : Theme.textColor
        }

        MouseArea {
          id: categoryMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.selectCategory(categoryButton.index)
        }
      }
    }
  }

  Rectangle {
    id: railDivider
    anchors.left: rail.right
    anchors.leftMargin: 14
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: 20
    anchors.bottomMargin: 20
    width: 1
    color: Theme.separatorColor
  }

  // Clicking anywhere else closes an open list.
  MouseArea {
    anchors.fill: parent
    z: 5
    enabled: root.openKey !== ""
    onClicked: root.openKey = ""
  }

  Column {
    anchors.left: railDivider.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: hint.top
    anchors.margins: 20
    anchors.bottomMargin: 10
    spacing: 10
    // Above the click-away area while a list is open, so it can be used.
    z: root.openKey !== "" ? 10 : 0

    Item {
      id: titleRow
      width: parent.width
      height: resetButton.implicitHeight

      ThemedText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.categories[root.category].label
        sizeScale: 1.2
      }

      PowerMenuOption {
        id: resetButton
        anchors.right: parent.right
        label: I18n.tr("settings.reset")
        // This page only: to your own defaults, else the built-in ones.
        onClicked: SettingsPages.restoreDefaults(root.page, "mine")
      }
    }

    // The tabs of a category that has them.
    TabBar {
      id: tabBar
      visible: root.tabs.length > 0
      width: parent.width
      model: root.tabs
      // The panel is built anew each time it opens, on the tab last shown.
      currentIndex: root.tab
      onCurrentIndexChanged: if (currentIndex !== root.tab) root.selectTab(currentIndex)
    }

    // The rows of the category, scrolling when there are more than fit (the
    // widgets category has one per bar widget).
    Item {
      id: viewport
      width: parent.width
      height: parent.height - titleRow.height - parent.spacing - (tabBar.visible ? tabBar.height + parent.spacing : 0)

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: rowsColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Scrolls just enough to have row `index` fully in view.
        function reveal(index) {
          const item = rowsRepeater.itemAt(index)
          if (!item) return
          if (item.y < scroller.contentY) scroller.contentY = item.y
          else if (item.y + item.height > scroller.contentY + scroller.height) scroller.contentY = Math.min(item.y, item.y + item.height - scroller.height)
        }

        Connections {
          target: root

          // (Later: a row that moved is only in its new place by then.)
          function onSelectedChanged() {
            Qt.callLater(() => scroller.reveal(root.selected))
          }

          // A list that opens makes its row taller: show all of it.
          function onOpenKeyChanged() {
            Qt.callLater(() => scroller.reveal(root.selected))
          }

          function onPageChanged() {
            scroller.contentY = 0
          }
        }

        Column {
          id: rowsColumn
          // Leaves room for the scroll bar.
          width: scroller.width - 10
          spacing: 6

          Repeater {
            id: rowsRepeater
            model: ScriptModel {
              values: root.rows
              objectProp: "key"
            }

            Item {
              id: row

              required property var modelData
              required property int index

              // A title over the row: the row's own `title` (the launcher's
              // engines, the settings' sections).
              readonly property string title: row.modelData.title ?? ""
              readonly property real titleHeight: row.title !== "" ? 34 : 0
              readonly property real gapHeight: row.modelData.kind === "defaults" ? 16 : 0
              readonly property real above: row.titleHeight + row.gapHeight
              // The least width this row needs: that of the row shown in it
              // (a dropdown's list has its own width, and does not count).
              readonly property real need: [sliderRow, engineRow, matugenAppRow, layoutLoader, toggleRow, pathRow, buttonsRow, choiceRow, dropdown, defaultsRow, factoryRow]
                .reduce((most, item) => item.visible ? Math.max(most, item.implicitWidth + item.anchors.leftMargin) : most, 0)

              width: parent.width
              height: row.modelData.kind === "layoutEditor" ? layoutLoader.implicitHeight + row.above : row.modelData.kind === "matugenApp" ? 84 + row.above : row.modelData.kind === "engine" ? 44 + row.above : (row.modelData.kind === "defaults" ? 54 + row.above : (row.modelData.kind === "factoryAll" ? 54 : (row.modelData.kind === "slider" ? sliderRow.implicitHeight + 10 : 64) + row.above))

              // The name of the section, with a line after it.
              ThemedText {
                id: titleText
                visible: row.titleHeight > 0
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.bottom: parent.top
                anchors.bottomMargin: -row.titleHeight + 6
                text: row.title
                sizeScale: 0.75
                font.bold: true
                opacity: 0.7
              }

              Rectangle {
                visible: row.titleHeight > 0
                anchors.left: titleText.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: titleText.verticalCenter
                height: 1
                color: Theme.separatorColor
                opacity: 0.6
              }

              // A row with a button that opens something (the notification
              // actions panel).
              DefaultsRow {
                visible: row.modelData.kind === "action"
                anchors.fill: parent
                anchors.topMargin: row.above
                label: row.modelData.label
                buttons: row.modelData.kind === "action" ? [{ text: root.actionButtonText(row.modelData), enabled: true }] : []
                selected: root.selected === row.index
                focusIndex: 0
                onActivated: root.selected = row.index
                onPressed: root.runAction(row.modelData)
              }

              // The factory reset of every category, with its confirmation.
              DefaultsRow {
                id: factoryRow
                visible: row.modelData.kind === "factoryAll"
                anchors.fill: parent
                label: root.confirmAll ? I18n.tr("settings.factoryAll.confirm") : row.modelData.label
                buttons: root.confirmAll ? [
                  { text: I18n.tr("common.confirm"), enabled: true },
                  { text: I18n.tr("common.cancel"), enabled: true }
                ] : [
                  { text: I18n.tr("settings.defaults.factory"), enabled: true }
                ]
                selected: root.selected === row.index
                focusIndex: root.toggleFocus
                onActivated: root.selected = row.index
                onPressed: index => root.pressFactoryAll(index)
              }

              // A line above the defaults row.
              Rectangle {
                visible: row.modelData.kind === "defaults"
                anchors.left: parent.left
                anchors.right: parent.right
                y: 6
                height: 1
                color: Theme.separatorColor
                opacity: 0.6
              }

              DefaultsRow {
                id: defaultsRow
                visible: row.modelData.kind === "defaults"
                anchors.fill: parent
                anchors.topMargin: row.above
                readonly property bool asking: root.confirmKey === row.modelData.category
                label: asking ? I18n.tr("settings.defaults.confirm") : row.modelData.label
                buttons: asking ? [
                  { text: I18n.tr("common.confirm"), enabled: true },
                  { text: I18n.tr("common.cancel"), enabled: true }
                ] : [
                  { text: I18n.tr("settings.defaults.save"), enabled: true },
                  { text: I18n.tr("settings.defaults.factory"), enabled: true }
                ]
                selected: root.selected === row.index
                focusIndex: root.toggleFocus
                onActivated: root.selected = row.index
                onPressed: index => root.pressDefaults(row.modelData.category, index)
              }

              SettingSlider {
                id: sliderRow
                controlX: root.controlX
                visible: row.modelData.kind === "slider"
                anchors.fill: parent
                anchors.topMargin: row.above
                label: row.modelData.label
                from: row.modelData.kind === "slider" ? Settings.limits[row.modelData.key][0] : 0
                to: row.modelData.kind === "slider" ? Settings.limits[row.modelData.key][1] : 1
                stepSize: row.modelData.step ?? 1
                valueWidth: sliderValues.implicitWidth
                value: row.modelData.kind === "slider" ? root.sliderValueOf(row.modelData) : 0
                valueText: row.modelData.kind === "slider" ? row.modelData.format(root.sliderValueOf(row.modelData)) : ""
                selected: root.selected === row.index
                interactive: root.rowEnabled(row.modelData)
                disabledReason: root.disabledReasonOf(row.modelData)
                tooltip: row.modelData.tooltip ?? ""
                stepper: row.modelData.stepper ?? false
                editing: root.editKey === row.modelData.key
                onEditRequested: root.editKey = row.modelData.key
                onCommitted: value => {
                  root.editKey = ""
                  Settings.set(row.modelData.key, value)
                }
                onCancelled: root.editKey = ""
                onReleased: root.focusTarget.forceActiveFocus()
                sameText: row.modelData.sameText ?? ""
                same: row.modelData.same ? Settings.get(row.modelData.same) : false
                onSameToggled: Settings.set(row.modelData.same, !Settings.get(row.modelData.same))
                note: row.modelData.key === "workspaceCount" ? I18n.tr("settings.workspaceCount.note", WorkspaceRules.configured.length) : ""
                onActivated: root.selected = row.index
                onMoved: value => Settings.set(row.modelData.key, value)
              }

              SearchEngineRow {
                id: engineRow
                readonly property string prefix: row.modelData.key + ":"

                visible: row.modelData.kind === "engine"
                anchors.fill: parent
                anchors.topMargin: row.above
                browser: row.modelData.engine?.browser ?? false
                label: row.modelData.label
                name: row.modelData.engine?.name ?? ""
                url: row.modelData.engine?.url ?? ""
                on: row.modelData.engine?.on ?? false
                canMoveBack: row.modelData.canMoveBack ?? false
                canMoveForward: row.modelData.canMoveForward ?? false
                selected: root.selected === row.index
                focusIndex: root.toggleFocus
                editing: root.editKey.startsWith(engineRow.prefix) ? root.editKey.slice(engineRow.prefix.length) : ""
                onActivated: root.selected = row.index
                onToggled: Settings.setEngine(row.modelData.engineIndex, { on: !row.modelData.engine.on })
                onMoved: steps => root.moveEngine(row.modelData, steps)
                onRemoved: Settings.removeEngine(row.modelData.engineIndex)
                onEditRequested: field => {
                  root.toggleFocus = field === "name" ? 1 : 2
                  root.editKey = engineRow.prefix + field
                }
                // A refused value (no name, or an address without %s)
                // leaves the field open to be typed again.
                onCommitted: (field, text) => {
                  const fields = {}
                  fields[field] = text.trim()
                  if (Settings.setEngine(row.modelData.engineIndex, fields)) root.editKey = ""
                }
                onCancelled: root.editKey = ""
                onReleased: root.focusTarget.forceActiveFocus()
              }

              // The bar layout editor, made only for its own row.
              Loader {
                id: layoutLoader
                visible: row.modelData.kind === "layoutEditor"
                active: visible
                anchors.fill: parent
                anchors.topMargin: row.above
                sourceComponent: BarLayoutEditor {}
              }

              ThemeAppRow {
                id: matugenAppRow
                readonly property string prefix: row.modelData.key + ":"

                visible: row.modelData.kind === "matugenApp"
                anchors.fill: parent
                anchors.topMargin: row.above
                name: row.modelData.app?.name ?? ""
                template: row.modelData.app?.template ?? ""
                output: row.modelData.app?.output ?? ""
                hook: row.modelData.app?.hook ?? ""
                on: row.modelData.app?.on ?? false
                selected: root.selected === row.index
                focusIndex: root.toggleFocus
                editing: root.editKey.startsWith(matugenAppRow.prefix) ? root.editKey.slice(matugenAppRow.prefix.length) : ""
                onActivated: root.selected = row.index
                onToggled: Settings.setMatugenApp(row.modelData.appIndex, { on: !row.modelData.app.on })
                onRemoved: Settings.removeMatugenApp(row.modelData.appIndex)
                onEditRequested: field => {
                  root.toggleFocus = root.matugenAppFields.indexOf(field)
                  root.editKey = matugenAppRow.prefix + field
                }
                // An empty name is refused: the field stays open to be typed again.
                onCommitted: (field, text) => {
                  const fields = {}
                  fields[field] = text.trim()
                  if (Settings.setMatugenApp(row.modelData.appIndex, fields)) root.editKey = ""
                }
                onCancelled: root.editKey = ""
                onReleased: root.focusTarget.forceActiveFocus()
              }

              ToggleRow {
                id: toggleRow
                controlX: root.controlX
                visible: row.modelData.kind === "toggles"
                anchors.fill: parent
                anchors.topMargin: row.above
                label: row.modelData.label
                options: row.modelData.toggles ?? []
                checkBoxes: row.modelData.checkBoxes ?? false
                checked: root.checkedOf(row.modelData)
                selected: root.selected === row.index
                focusIndex: root.toggleFocus
                interactive: root.rowEnabled(row.modelData)
                disabledReason: root.disabledReasonOf(row.modelData)
                onActivated: {
                  root.selected = row.index
                }
                onToggled: key => {
                  root.toggleFocus = (row.modelData.toggles ?? []).findIndex(option => option.key === key)
                  Settings.set(key, !Settings.get(key))
                }
              }

              PathRow {
                id: pathRow
                controlX: root.controlX
                visible: row.modelData.kind === "path"
                anchors.fill: parent
                anchors.topMargin: row.above
                label: row.modelData.label
                value: row.modelData.kind === "path" ? String(Settings.get(row.modelData.key)) : ""
                placeholder: row.modelData.placeholder ?? ""
                swatch: row.modelData.swatch ? String(Settings.get(row.modelData.key)) : ""
                selected: root.selected === row.index
                editing: root.editKey === row.modelData.key
                onActivated: root.selected = row.index
                onEditRequested: root.editKey = row.modelData.key
                onCommitted: text => {
                  root.editKey = ""
                  Settings.set(row.modelData.key, text)
                }
                onCancelled: root.editKey = ""
                onReleased: root.focusTarget.forceActiveFocus()
                onPicked: value => Settings.set(row.modelData.key, value)
                // Out of the way while a color is picked from the screen.
                // (Resuming first, so the panel stays built while hidden.)
                onScreenPickStarted: {
                  SettingsPanelState.resuming = true
                  SettingsPanelState.visible = false
                }
                onScreenPickFinished: SettingsPanelState.visible = true
              }

              DropdownRow {
                id: dropdown
                controlX: root.controlX
                visible: row.modelData.kind === "dropdown"
                anchors.fill: parent
                anchors.topMargin: row.above
                label: row.modelData.label
                options: root.optionsOf(row.modelData)
                current: row.modelData.kind === "dropdown" ? root.currentOf(row.modelData) : null
                selected: root.selected === row.index
                headerHeight: 64
                open: root.openKey === row.modelData.key
                highlighted: root.highlight
                previewFonts: row.modelData.key === "fontFamily"
                positionIcon: row.modelData.positionIcon ?? false
                // Every list floats over the panel, so nothing moves when one opens.
                overlay: true
                interactive: root.rowEnabled(row.modelData)
                disabledReason: root.disabledReasonOf(row.modelData)
                onActivated: root.selected = row.index
                onToggled: root.toggleDropdown(row.modelData)
                onHighlightRequested: index => root.highlight = index
                onChosen: value => {
                  // Close first: applying it may rebuild what the list belongs to.
                  root.openKey = ""
                  Settings.set(row.modelData.key, value)
                }
                onOverlayKeyPressed: event => root.listKeyPressed(event)
              }

              ChoiceRow {
                id: buttonsRow
                controlX: root.controlX
                visible: row.modelData.kind === "buttons"
                anchors.fill: parent
                anchors.topMargin: row.above
                literal: true
                label: row.modelData.label
                options: root.optionsOf(row.modelData)
                current: row.modelData.kind === "buttons" ? root.currentOf(row.modelData) : null
                selected: root.selected === row.index
                interactive: root.rowEnabled(row.modelData)
                disabledReason: root.disabledReasonOf(row.modelData)
                onActivated: root.selected = row.index
                onChosen: value => Settings.set(row.modelData.key, value)
              }

              ChoiceRow {
                id: choiceRow
                controlX: root.controlX
                visible: row.modelData.kind === "choice"
                anchors.fill: parent
                anchors.topMargin: row.above
                label: row.modelData.label
                options: root.languageOptions
                current: I18n.setting
                selected: root.selected === row.index
                onActivated: root.selected = row.index
                onChosen: value => I18n.select(value)
              }
            }
          }
        }
      }

      // Where the visible part is, when the rows don't all fit.
      Rectangle {
        visible: scroller.visibleArea.heightRatio < 1
        anchors.right: parent.right
        y: scroller.visibleArea.yPosition * scroller.height
        width: 4
        height: scroller.visibleArea.heightRatio * scroller.height
        radius: 2
        color: Theme.textColor
        opacity: 0.4
      }
    }
  }

  ThemedText {
    id: hint
    anchors.left: railDivider.right
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 20
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: I18n.tr("settings.hint")
    opacity: 0.5
    sizeScale: 0.65
  }
}
