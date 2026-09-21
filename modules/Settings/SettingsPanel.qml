import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// Settings panel, toggled from outside via:
//   quickshell -p . ipc call settings toggle
// Each setting applies as soon as it's changed and is remembered (see
// Settings.qml; the language by I18n). Click or drag a slider, or use the
// keys: Up/Down select a row, Left/Right adjust it (Shift for bigger steps),
// PageUp/PageDown switch category, Escape closes. Enter opens the list of a
// dropdown row (Up/Down then move in it, Enter picks, Escape closes just the
// list); on the font style row, Left/Right move between the buttons and Enter
// switches one. The rows are grouped in categories, chosen with the icons on the left.
ModalPanel {
  id: root

  // The categories, top to bottom in the icon rail.
  readonly property var categories: [
    { id: "appearance", icon: "󰏘", label: I18n.tr("settings.category.appearance") },
    { id: "text", icon: "󰛖", label: I18n.tr("settings.category.text") },
    { id: "bar", icon: "󰍜", label: I18n.tr("settings.category.bar") },
    { id: "widgets", icon: "󰀻", label: I18n.tr("settings.category.widgets") },
    { id: "wallpaper", icon: "󰋩", label: I18n.tr("settings.category.wallpaper") },
    { id: "notifications", icon: "󰂚", label: I18n.tr("settings.category.notifications") },
    { id: "general", icon: "󰒓", label: I18n.tr("settings.category.general") }
  ]

  // The rows of every category, top to bottom. Sliders take their range from
  // Settings.limits.
  readonly property var allRows: [
    { key: "radius", category: "appearance", kind: "slider", label: I18n.tr("settings.radius"), step: 1, format: v => v + " px" },
    { key: "language", category: "general", kind: "choice", label: I18n.tr("settings.language") },
    { key: "screenshotDir", category: "general", kind: "path", label: I18n.tr("settings.screenshotDir") },
    { key: "factoryAll", category: "general", kind: "factoryAll", label: I18n.tr("settings.factoryAll") },
    { key: "opacity", category: "appearance", kind: "slider", label: I18n.tr("settings.opacity"), step: 0.05, format: v => Math.round(v * 100) + " %" },
    { key: "spacing", category: "appearance", kind: "slider", label: I18n.tr("settings.spacing"), step: 1, format: v => v + " px" },
    { key: "barHeight", category: "bar", kind: "slider", label: I18n.tr("settings.barHeight"), step: 1, format: v => v + " px" },
    { key: "barMarginTop", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginTop"), step: 1, format: v => v + " px" },
    { key: "barMarginBottom", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginBottom"), step: 1, format: v => v + " px" },
    { key: "barMarginLeft", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginLeft"), step: 5, format: v => v + " px" },
    { key: "barMarginRight", category: "bar", kind: "slider", label: I18n.tr("settings.barMarginRight"), step: 5, format: v => v + " px" },
    { key: "borderWidth", category: "appearance", kind: "slider", label: I18n.tr("settings.borderWidth"), step: 1, format: v => v + " px" },
    { key: "fontSize", category: "text", kind: "slider", label: I18n.tr("settings.fontSize"), step: 1, format: v => v + " px" },
    { key: "fontWeight", category: "text", kind: "slider", label: I18n.tr("settings.fontWeight"), step: 100, format: v => I18n.tr("settings.weight." + v) },
    { key: "fontLetterSpacing", category: "text", kind: "slider", label: I18n.tr("settings.fontLetterSpacing"), step: 0.5, format: v => v.toFixed(1) + " px" },
    { key: "fontCaps", category: "text", kind: "buttons", label: I18n.tr("settings.fontCaps") },
    { key: "fontStyle", category: "text", kind: "toggles", label: I18n.tr("settings.fontStyle"), toggles: [
      { key: "fontItalic", text: I18n.tr("settings.fontItalic"), italic: true },
      { key: "fontUnderline", text: I18n.tr("settings.fontUnderline"), underline: true },
      { key: "fontOutline", text: I18n.tr("settings.fontOutline") }
    ] },
    { key: "fontFamily", category: "text", kind: "dropdown", label: I18n.tr("settings.fontFamily") },
    { key: "wallpaperTransition", category: "wallpaper", kind: "dropdown", label: I18n.tr("settings.wallpaperTransition") },
    { key: "wallpaperDuration", category: "wallpaper", kind: "slider", label: I18n.tr("settings.wallpaperDuration"), step: 0.5, format: v => v.toFixed(1) + " s" },
    { key: "notificationTimeout", category: "notifications", kind: "slider", label: I18n.tr("settings.notificationTimeout"), step: 1, format: v => v + " s" },
    { key: "notificationMax", category: "notifications", kind: "slider", label: I18n.tr("settings.notificationMax"), step: 1, format: v => String(v) },
    { key: "notificationPosition", category: "notifications", kind: "dropdown", positionIcon: true, label: I18n.tr("settings.notificationPosition") },
    { key: "notificationDndRow", category: "notifications", kind: "toggles", checkBoxes: true, label: I18n.tr("settings.notificationDnd"), toggles: [
      { key: "notificationDnd", text: "" }
    ] }
  ].concat(root.widgetRows).concat(root.defaultRows)

  // The last row of every category: its defaults (see DefaultsRow).
  readonly property var defaultRows: root.categories.map(category => ({
    key: "defaults:" + category.id, category: category.id, kind: "defaults", label: I18n.tr("settings.defaults")
  }))

  // The widgets category, in the order things are on the bar: for each
  // section (left, center, right) its groups (the widgets between two
  // dividers), each a "group" row (its mode, and moving it) followed by a row
  // per widget; then the widgets that are off. Rows say where they are in
  // their section and group so the panel can draw each group as a block:
  // `zoneStart` for the first row of a section, `groupStart` for a group's
  // first row and `groupEnd` for its last. A group row's `widget` is the
  // widget that starts the group, which names it.
  readonly property var widgetRows: {
    const rows = []
    const widgetRow = (id, zone, zoneStart, groupEnd) => ({
      key: "widget:" + id,
      widget: id,
      category: "widgets",
      kind: "widget",
      label: I18n.tr("settings.widget." + id),
      zone: zone,
      zoneStart: zoneStart,
      groupStart: false,
      groupEnd: groupEnd
    })
    for (const zone of Settings.zones) {
      const groups = Settings.groupsOf(zone)
      groups.forEach((group, groupIndex) => {
        rows.push({
          key: "group:" + group[0],
          widget: group[0],
          category: "widgets",
          kind: "group",
          label: I18n.tr("settings.group") + " " + (groupIndex + 1),
          zone: zone,
          shown: !Settings.hiddenGroups.includes(group[0]),
          hover: Settings.collapsed.includes(group[0]),
          canMoveBack: groupIndex > 0,
          canMoveForward: groupIndex < groups.length - 1,
          zoneStart: groupIndex === 0,
          groupStart: true,
          groupEnd: false
        })
        group.forEach((id, index) => rows.push(widgetRow(id, zone, false, index === group.length - 1)))
      })
    }
    const off = Settings.widgetIds.filter(id => Settings.zoneOf(id) === "off")
    off.forEach((id, index) => rows.push(widgetRow(id, "off", index === 0, false)))
    return rows
  }

  // The pop-up positions, named in the current language.
  readonly property var positionOptions: Settings.choices.notificationPosition
    .map(name => ({ value: name, text: I18n.tr("settings.position." + name) }))

  // The wallpaper transitions, named in the current language.
  readonly property var transitionOptions: Settings.choices.wallpaperTransition
    .map(name => ({ value: name, text: I18n.tr("settings.transition." + name) }))

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

  // Where a widget can be put, for its row: one of the three zones (off is
  // the check box).
  readonly property var zoneOptions: Settings.zones
    .map(name => ({ value: name, text: I18n.tr("settings.zone." + name) }))

  // The capitalizations, named in the current language.
  readonly property var capsOptions: Settings.choices.fontCaps
    .map(name => ({
      value: name,
      text: I18n.tr("settings.caps." + name),
      capitalization: name === "small" ? Font.SmallCaps : Font.MixedCase
    }))

  // The options of a buttons or dropdown row.
  function optionsOf(row) {
    if (row.key === "fontFamily") return root.fontOptions
    if (row.key === "fontCaps") return root.capsOptions
    if (row.key === "wallpaperTransition") return root.transitionOptions
    if (row.key === "notificationPosition") return root.positionOptions
    return []
  }

  // Language choices: follow the system, or one of the supported languages.
  readonly property var languageOptions: [{ value: "auto", text: I18n.tr("settings.language.auto") }]
    .concat(I18n.supported.map(code => ({ value: code, text: I18n.languageNames[code] })))

  property int category: 0
  // The rows of the current category; `selected` indexes into these.
  readonly property var rows: root.allRows.filter(row => row.category === root.categories[root.category].id)
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
  maxPanelHeight: 780
  // Stays readable while the widget opacity is being adjusted.
  panelOpacity: Math.max(0.92, Theme.widgetOpacity)

  visible: SettingsPanelState.visible
  // Escape closes an open list first, then the panel.
  onCloseRequested: {
    if (root.confirmAll) root.confirmAll = false
    else if (root.confirmKey !== "") root.confirmKey = ""
    else if (root.editKey !== "") root.editKey = ""
    else if (root.openKey !== "") root.openKey = ""
    else SettingsPanelState.visible = false
  }
  Component.onCompleted: root.refreshFontOptions()
  onOpened: {
    root.selected = 0
    root.openKey = ""
    root.refreshFontOptions()
  }
  onSelectedChanged: {
    root.syncSelectedKey()
    root.openKey = ""
    root.editKey = ""
    root.confirmKey = ""
    root.confirmAll = false
    root.toggleFocus = 0
  }

  IpcHandler {
    target: "settings"

    function toggle(): void {
      SettingsPanelState.toggle()
    }

    // Sets one numeric setting by name (radius, opacity, spacing, barHeight,
    // barMarginTop, barMarginBottom, barMarginLeft, barMarginRight, borderWidth,
    // fontSize, fontWeight, fontLetterSpacing, wallpaperDuration); out-of-range
    // values are clamped. The font style settings (fontItalic, fontUnderline,
    // fontOutline) take 1 or 0.
    function set(key: string, value: real): void {
      Settings.set(key, value)
    }

    // Puts a bar widget in a zone ("left", "center", "right", or "off" to hide
    // it; the widget ids are launcher, settings, workspaces, activeWindow,
    // clock, wallpaper, theme, tray, cpu, ram, disk, network, volume, power),
    // at the end of it, or `position` places from its start when not negative.
    function place(widget: string, zone: string, position: int): void {
      Settings.place(widget, zone, position < 0 ? undefined : position)
    }

    // Puts a bar widget on the bar (1: back where it was, else where it is by
    // default) or takes it off (0).
    function widgetShown(widget: string, on: int): void {
      Settings.setWidgetShown(widget, on !== 0)
    }

    // Moves a bar widget `steps` places later (negative: earlier) in its zone.
    function move(widget: string, steps: int): void {
      Settings.move(widget, steps)
    }

    // Turns the divider before a bar widget on (1) or off (0). It shows when
    // the widget is shown and something shown comes before it in its pill.
    function divider(widget: string, on: int): void {
      Settings.setDivider(widget, on !== 0)
    }

    // Sets the mode of the group that widget starts: "on", "hover" (shown only
    // while its pill is hovered) or "off". A group starts at the first widget
    // of a pill and at each widget with a divider before it.
    function group(widget: string, mode: string): void {
      Settings.setGroupMode(widget, mode)
    }

    // Moves the group that widget starts `steps` places later (negative:
    // earlier) in its pill.
    function moveGroup(widget: string, steps: int): void {
      Settings.moveGroup(widget, steps)
    }

    // The bar's layout as JSON: { "left": [ids], "center": [ids], "right":
    // [ids], "dividers": [the ids with a divider before them], "collapsed":
    // [the widgets starting a group shown only on hover], "off": [the widgets
    // starting a group that is off] }.
    function layout(): string {
      return JSON.stringify(Object.assign({}, Settings.layout, { dividers: Settings.dividers, collapsed: Settings.collapsed, off: Settings.hiddenGroups }))
    }

    function get(key: string): real {
      return Settings.get(key)
    }

    // The same for a setting with a fixed list of choices (wallpaperTransition,
    // fontCaps;
    // a value not in the list is ignored) and for the font family (any
    // installed family, e.g. "DejaVu Sans Mono").
    function choose(key: string, value: string): void {
      const allowed = key === "fontFamily" ? Qt.fontFamilies().includes(value) : Settings.choices[key]?.includes(value)
      if (allowed) Settings.set(key, value)
    }

    function getChoice(key: string): string {
      return String(Settings.get(key))
    }

    // Puts every setting, and the language, back to the built-in defaults and
    // saves them as your defaults too, without asking (the panel's button
    // asks first).
    function factoryReset(): void {
      root.factoryResetAll()
    }

    // Puts every setting, and the language, back to your own defaults (the
    // built-in ones for what you have saved none for).
    function reset(): void {
      root.resetAll()
    }

    // Saves the current values of a category (appearance, text, bar, widgets,
    // wallpaper, notifications or general) as your own defaults.
    function saveDefaults(category: string): void {
      if (root.categories.some(candidate => candidate.id === category)) root.saveDefaults(category)
    }

    // Puts a category back to your own defaults (source "mine") or to the
    // built-in ones ("factory").
    function restoreDefaults(category: string, source: string): void {
      if (root.categories.some(candidate => candidate.id === category) && (source === "mine" || source === "factory")) {
        root.restoreDefaults(category, source)
      }
    }
  }

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
    if (categoryId === "widgets") return ["barLeft", "barCenter", "barRight", "barDividers", "barCollapsed", "barGroupsOff"]
    const keys = []
    for (const row of root.allRows) {
      if (row.category !== categoryId) continue
      if (Settings.defaults[row.key] !== undefined) keys.push(row.key)
      for (const toggle of row.toggles ?? []) keys.push(toggle.key)
    }
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

  // Whether the factory reset of everything (the general category's row) waits
  // for its confirmation.
  property bool confirmAll: false

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

  // The button of the "all categories" row: Factory defaults, which asks; or,
  // while asking, Confirm (0) and Cancel (1).
  function pressFactoryAll(index) {
    if (!root.confirmAll) {
      root.confirmAll = true
      // On Cancel, the safe answer.
      root.toggleFocus = 1
    } else {
      if (index === 0) root.factoryResetAll()
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
        root.restoreDefaults(categoryId, "factory")
        root.saveDefaults(categoryId)
      }
      root.confirmKey = ""
    } else if (index === 0) {
      root.saveDefaults(categoryId)
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
    root.selected = 0
  }

  // Moves the selected row's value one step (or `steps` of them) up or down.
  function adjust(direction, steps) {
    const row = root.rows[root.selected]
    if (row.kind === "slider") {
      Settings.set(row.key, Settings.get(row.key) + direction * row.step * steps)
    } else if (row.kind === "dropdown" || row.kind === "buttons") {
      const values = root.optionsOf(row).map(option => option.value)
      const next = ((values.indexOf(Settings.get(row.key)) + direction * steps) % values.length + values.length) % values.length
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

  // Keys while a list is open: they move in it, pick from it, and nothing
  // else (Escape, handled by the panel, closes it).
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
    if (kind === "widget" && event.key === Qt.Key_D && Settings.layout[Settings.zoneOf(root.rows[root.selected].widget)]?.[0] === root.rows[root.selected].widget) {
      // The first widget of a pill has no divider to switch.
      event.accepted = true
    } else if (kind === "path" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      // Enter: type in the field.
      root.editKey = root.rows[root.selected].key
      event.accepted = true
    } else if (kind === "group" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Left / Right: the check box the keys are on (on, on hover); with
      // Shift: the whole group earlier / later in its pill.
      const row = root.rows[root.selected]
      const direction = event.key === Qt.Key_Left ? -1 : 1
      if (big) Settings.moveGroup(row.widget, direction)
      else root.toggleFocus = Math.max(0, Math.min(1, root.toggleFocus + direction))
      event.accepted = true
    } else if (kind === "group" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      // Enter / Space: tick or untick the check box the keys are on.
      const row = root.rows[root.selected]
      if (root.toggleFocus === 0) Settings.setGroupShown(row.widget, !row.shown)
      else Settings.setGroupHover(row.widget, !row.hover)
      event.accepted = true
    } else if (kind === "widget" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      // Enter / Space: put the widget on the bar or take it off.
      const id = root.rows[root.selected].widget
      Settings.setWidgetShown(id, Settings.zoneOf(id) === "off")
      event.accepted = true
    } else if (kind === "widget" && event.key === Qt.Key_D) {
      // D: the divider before the widget, on or off.
      const id = root.rows[root.selected].widget
      Settings.setDivider(id, !Settings.dividers.includes(id))
      event.accepted = true
    } else if (kind === "widget" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Left / Right: another zone; with Shift: earlier / later in this one.
      const id = root.rows[root.selected].widget
      const direction = event.key === Qt.Key_Left ? -1 : 1
      if (big) {
        Settings.move(id, direction)
      } else {
        const zones = id === "settings" ? Settings.zones : ["off"].concat(Settings.zones)
        const next = zones.indexOf(Settings.zoneOf(id)) + direction
        if (next >= 0 && next < zones.length) Settings.place(id, zones[next])
      }
      event.accepted = true
    } else if (kind === "factoryAll" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
      // Move between Confirm and Cancel, while asking.
      root.toggleFocus = Math.max(0, Math.min(root.confirmAll ? 1 : 0, root.toggleFocus + (event.key === Qt.Key_Left ? -1 : 1)))
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
    } else if (kind === "toggles" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
      const key = root.rows[root.selected].toggles[root.toggleFocus].key
      Settings.set(key, !Settings.get(key))
      event.accepted = true
    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
        && root.rows[root.selected].kind === "dropdown") {
      root.toggleDropdown(root.rows[root.selected])
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

  // Not shown either: the widget names, to give them all the width of the
  // widest so the check boxes after them line up.
  Column {
    id: widgetLabels
    opacity: 0

    Repeater {
      model: Settings.widgetIds

      ThemedText {
        required property string modelData
        text: I18n.tr("settings.widget." + modelData)
      }
    }
  }

  // Category buttons, one per page of settings: an icon and the name.
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
          x: 0
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
        // This category only: to your own defaults, else the built-in ones.
        onClicked: root.restoreDefaults(root.categories[root.category].id, "mine")
      }
    }

    // The rows of the category, scrolling when there are more than fit (the
    // widgets category has one per bar widget).
    Item {
      id: viewport
      width: parent.width
      height: parent.height - titleRow.height - parent.spacing

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

          function onCategoryChanged() {
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

              // A widget row that starts a section has that section's name
              // above it, and one that starts a group has a gap above it.
              readonly property bool isWidget: row.modelData.kind === "widget" || row.modelData.kind === "group"
              readonly property real titleHeight: row.isWidget && row.modelData.zoneStart ? 34 : 0
              readonly property real gapHeight: row.modelData.kind === "defaults" ? 16 : (row.isWidget && row.modelData.groupStart && !row.modelData.zoneStart ? 12 : 0)
              readonly property real above: row.titleHeight + row.gapHeight
              // The least width this row needs: that of the row shown in it
              // (a dropdown's list has its own width, and does not count).
              readonly property real need: [sliderRow, groupRow, widgetRow, toggleRow, pathRow, buttonsRow, choiceRow, dropdown, defaultsRow, factoryRow]
                .reduce((most, item) => item.visible ? Math.max(most, item.implicitWidth + item.anchors.leftMargin) : most, 0)

              width: parent.width
              // A dropdown row grows to hold its list while it's open.
              height: row.modelData.kind === "dropdown" ? dropdown.implicitHeight : (row.isWidget ? 38 + row.above : (row.modelData.kind === "defaults" ? 54 + row.above : (row.modelData.kind === "factoryAll" ? 54 : 64)))

              // The name of the section, with a line after it.
              ThemedText {
                id: zoneTitle
                visible: row.titleHeight > 0
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.bottom: parent.top
                anchors.bottomMargin: -row.titleHeight + 6
                text: row.isWidget ? I18n.tr("settings.zone." + row.modelData.zone) : ""
                sizeScale: 0.75
                font.bold: true
                opacity: 0.7
              }

              Rectangle {
                visible: row.titleHeight > 0
                anchors.left: zoneTitle.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: zoneTitle.verticalCenter
                height: 1
                color: Theme.separatorColor
                opacity: 0.6
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

              // The group as a block: a tinted background and a bar on its left,
              // continuing through the little gap between its rows.
              Rectangle {
                id: groupBlock
                readonly property real bridge: 3
                visible: row.isWidget && row.modelData.zone !== "off"
                x: 0
                y: row.above - (row.modelData.groupStart ? 0 : groupBlock.bridge)
                width: parent.width
                height: 38 + (row.modelData.groupStart ? 0 : groupBlock.bridge) + (row.modelData.groupEnd ? 0 : groupBlock.bridge)
                topLeftRadius: row.modelData.groupStart ? 10 : 0
                topRightRadius: row.modelData.groupStart ? 10 : 0
                bottomLeftRadius: row.modelData.groupEnd ? 10 : 0
                bottomRightRadius: row.modelData.groupEnd ? 10 : 0
                color: Qt.rgba(Theme.textColor.r, Theme.textColor.g, Theme.textColor.b, 0.06)

                Rectangle {
                  width: 3
                  height: parent.height
                  color: Theme.accentColor
                  opacity: 0.8
                }
              }

              SettingSlider {
                id: sliderRow
                visible: row.modelData.kind === "slider"
                anchors.fill: parent
                label: row.modelData.label
                from: row.modelData.kind === "slider" ? Settings.limits[row.modelData.key][0] : 0
                to: row.modelData.kind === "slider" ? Settings.limits[row.modelData.key][1] : 1
                stepSize: row.modelData.step ?? 1
                value: row.modelData.kind === "slider" ? Settings.get(row.modelData.key) : 0
                valueText: row.modelData.kind === "slider" ? row.modelData.format(Settings.get(row.modelData.key)) : ""
                selected: root.selected === row.index
                onActivated: root.selected = row.index
                onMoved: value => Settings.set(row.modelData.key, value)
              }

              GroupRow {
                id: groupRow
                visible: row.modelData.kind === "group"
                anchors.fill: parent
                anchors.topMargin: row.above
                anchors.leftMargin: 8
                label: row.modelData.label
                labelWidth: widgetLabels.implicitWidth
                hoverText: I18n.tr("settings.groupMode.hover")
                shown: row.modelData.shown ?? true
                hover: row.modelData.hover ?? false
                focusIndex: root.toggleFocus
                canMoveBack: row.modelData.canMoveBack ?? false
                canMoveForward: row.modelData.canMoveForward ?? false
                selected: root.selected === row.index
                onActivated: root.selected = row.index
                onShownToggled: Settings.setGroupShown(row.modelData.widget, !row.modelData.shown)
                onHoverToggled: Settings.setGroupHover(row.modelData.widget, !row.modelData.hover)
                onMoved: steps => Settings.moveGroup(row.modelData.widget, steps)
              }

              WidgetRow {
                id: widgetRow
                readonly property string widgetId: row.modelData.widget ?? ""
                readonly property string zoneNow: row.modelData.kind === "widget" ? Settings.zoneOf(widgetId) : "off"
                readonly property var placed: Settings.layout[zoneNow] ?? []

                visible: row.modelData.kind === "widget"
                anchors.fill: parent
                anchors.topMargin: row.above
                anchors.leftMargin: 8
                label: row.modelData.label
                zones: root.zoneOptions
                labelWidth: widgetLabels.implicitWidth
                shown: zoneNow !== "off"
                shownEnabled: widgetId !== "settings"
                zone: zoneNow
                divider: Settings.dividers.includes(widgetId)
                dividerEnabled: placed.indexOf(widgetId) !== 0
                canMoveBack: placed.indexOf(widgetId) > 0
                canMoveForward: placed.indexOf(widgetId) >= 0 && placed.indexOf(widgetId) < placed.length - 1
                selected: root.selected === row.index
                onActivated: root.selected = row.index
                onDividerToggled: Settings.setDivider(widgetId, !Settings.dividers.includes(widgetId))
                onShownToggled: Settings.setWidgetShown(widgetId, zoneNow === "off")
                onZoneChosen: value => Settings.place(widgetId, value)
                onMoved: steps => Settings.move(widgetId, steps)
              }

              ToggleRow {
                id: toggleRow
                visible: row.modelData.kind === "toggles"
                anchors.fill: parent
                label: row.modelData.label
                options: row.modelData.toggles ?? []
                checkBoxes: row.modelData.checkBoxes ?? false
                checked: root.checkedOf(row.modelData)
                selected: root.selected === row.index
                focusIndex: root.toggleFocus
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
                visible: row.modelData.kind === "path"
                anchors.fill: parent
                label: row.modelData.label
                value: row.modelData.kind === "path" ? String(Settings.get(row.modelData.key)) : ""
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
              }

              DropdownRow {
                id: dropdown
                visible: row.modelData.kind === "dropdown"
                anchors.fill: parent
                label: row.modelData.label
                options: root.optionsOf(row.modelData)
                current: row.modelData.kind === "dropdown" ? Settings.get(row.modelData.key) : null
                selected: root.selected === row.index
                headerHeight: 64
                open: root.openKey === row.modelData.key
                highlighted: root.highlight
                previewFonts: row.modelData.key === "fontFamily"
                positionIcon: row.modelData.positionIcon ?? false
                onActivated: root.selected = row.index
                onToggled: root.toggleDropdown(row.modelData)
                onHighlightRequested: index => root.highlight = index
                onChosen: value => {
                  // Close first: applying it may rebuild what the list belongs to.
                  root.openKey = ""
                  Settings.set(row.modelData.key, value)
                }
              }

              ChoiceRow {
                id: buttonsRow
                visible: row.modelData.kind === "buttons"
                anchors.fill: parent
                literal: true
                label: row.modelData.label
                options: root.optionsOf(row.modelData)
                current: row.modelData.kind === "buttons" ? Settings.get(row.modelData.key) : null
                selected: root.selected === row.index
                onActivated: root.selected = row.index
                onChosen: value => Settings.set(row.modelData.key, value)
              }

              ChoiceRow {
                id: choiceRow
                visible: row.modelData.kind === "choice"
                anchors.fill: parent
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
