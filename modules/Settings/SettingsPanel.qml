import QtQuick
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
    { id: "general", icon: "󰒓", label: I18n.tr("settings.category.general") }
  ]

  // The rows of every category, top to bottom. Sliders take their range from
  // Settings.limits.
  readonly property var allRows: [
    { key: "radius", category: "appearance", kind: "slider", label: I18n.tr("settings.radius"), step: 1, format: v => v + " px" },
    { key: "language", category: "general", kind: "choice", label: I18n.tr("settings.language") },
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
    { key: "wallpaperTransition", category: "wallpaper", kind: "cycle", label: I18n.tr("settings.wallpaperTransition") },
    { key: "wallpaperDuration", category: "wallpaper", kind: "slider", label: I18n.tr("settings.wallpaperDuration"), step: 0.5, format: v => v.toFixed(1) + " s" }
  ].concat(Settings.widgetIds.map(id => ({
    key: "widget:" + id, widget: id, category: "widgets", kind: "widget", label: I18n.tr("settings.widget." + id)
  })))

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

  // Where a widget can be put, for its row: off, or one of the three zones.
  readonly property var zoneOptions: ["off"].concat(Settings.zones)
    .map(name => ({ value: name, text: I18n.tr("settings.zone." + name) }))

  // The capitalizations, named in the current language.
  readonly property var capsOptions: Settings.choices.fontCaps
    .map(name => ({
      value: name,
      text: I18n.tr("settings.caps." + name),
      capitalization: name === "small" ? Font.SmallCaps : Font.MixedCase
    }))

  // The options of a cycle, buttons or dropdown row.
  function optionsOf(row) {
    if (row.key === "fontFamily") return root.fontOptions
    if (row.key === "fontCaps") return root.capsOptions
    if (row.key === "wallpaperTransition") return root.transitionOptions
    return []
  }

  // Language choices: follow the system, or one of the supported languages.
  readonly property var languageOptions: [{ value: "auto", text: I18n.tr("settings.language.auto") }]
    .concat(I18n.supported.map(code => ({ value: code, text: I18n.languageNames[code] })))

  property int category: 0
  // The rows of the current category; `selected` indexes into these.
  readonly property var rows: root.allRows.filter(row => row.category === root.categories[root.category].id)
  property int selected: 0
  // The row whose list of options is showing (its key, "" for none), and the
  // entry of that list the keys are on.
  property string openKey: ""
  property int highlight: 0

  maxPanelWidth: 920
  maxPanelHeight: 780
  // Stays readable while the widget opacity is being adjusted.
  panelOpacity: Math.max(0.92, Theme.widgetOpacity)

  visible: SettingsPanelState.visible
  // Escape closes an open list first, then the panel.
  onCloseRequested: {
    if (root.openKey !== "") root.openKey = ""
    else SettingsPanelState.visible = false
  }
  Component.onCompleted: root.refreshFontOptions()
  onOpened: {
    root.selected = 0
    root.openKey = ""
    root.refreshFontOptions()
  }
  onSelectedChanged: {
    root.openKey = ""
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

    // Moves a bar widget `steps` places later (negative: earlier) in its zone.
    function move(widget: string, steps: int): void {
      Settings.move(widget, steps)
    }

    // Turns the divider before a bar widget on (1) or off (0). It shows when
    // the widget is shown and something shown comes before it in its pill.
    function divider(widget: string, on: int): void {
      Settings.setDivider(widget, on !== 0)
    }

    // The bar's layout as JSON: { "left": [ids], "center": [ids], "right":
    // [ids], "dividers": [the ids with a divider before them] }.
    function layout(): string {
      return JSON.stringify(Object.assign({}, Settings.layout, { dividers: Settings.dividers }))
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

    // Puts every setting, and the language, back to its default.
    function reset(): void {
      root.resetAll()
    }
  }

  function resetAll() {
    Settings.reset()
    I18n.select("auto")
  }

  function selectCategory(index) {
    root.openKey = ""
    root.category = Math.max(0, Math.min(root.categories.length - 1, index))
    root.selected = 0
  }

  // Moves the selected row's value one step (or `steps` of them) up or down.
  function adjust(direction, steps) {
    const row = root.rows[root.selected]
    if (row.kind === "slider") {
      Settings.set(row.key, Settings.get(row.key) + direction * row.step * steps)
    } else if (row.kind === "cycle" || row.kind === "dropdown" || row.kind === "buttons") {
      const values = root.optionsOf(row).map(option => option.value)
      const next = ((values.indexOf(Settings.get(row.key)) + direction * steps) % values.length + values.length) % values.length
      Settings.set(row.key, values[next])
    } else {
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
    if (root.openKey !== "") {
      root.listKeyPressed(event)
      return
    }
    const big = (event.modifiers & Qt.ShiftModifier) !== 0
    const kind = root.rows[root.selected].kind
    if (kind === "widget" && event.key === Qt.Key_D) {
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
    anchors.bottom: parent.bottom
    anchors.margins: 20
    spacing: 10
    // Above the click-away area while a list is open, so it can be used.
    z: root.openKey !== "" ? 10 : 0

    Item {
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
        onClicked: root.resetAll()
      }
    }

    Column {
      width: parent.width
      spacing: 6

      Repeater {
        model: root.rows

        Item {
          id: row

          required property var modelData
          required property int index

          width: parent.width
          // A dropdown row grows to hold its list while it's open.
          height: row.modelData.kind === "dropdown" ? dropdown.implicitHeight : (row.modelData.kind === "widget" ? 38 : 64)

          SettingSlider {
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

          CycleRow {
            visible: row.modelData.kind === "cycle"
            anchors.fill: parent
            label: row.modelData.label
            options: root.optionsOf(row.modelData)
            current: row.modelData.kind === "cycle" ? Settings.get(row.modelData.key) : null
            selected: root.selected === row.index
            onActivated: root.selected = row.index
            onChosen: value => Settings.set(row.modelData.key, value)
          }

          WidgetRow {
            readonly property string widgetId: row.modelData.widget ?? ""
            readonly property string zoneNow: row.modelData.kind === "widget" ? Settings.zoneOf(widgetId) : "off"
            readonly property var placed: Settings.layout[zoneNow] ?? []

            visible: row.modelData.kind === "widget"
            anchors.fill: parent
            label: row.modelData.label
            zones: root.zoneOptions
            lockedZone: widgetId === "settings" ? "off" : ""
            zone: zoneNow
            divider: Settings.dividers.includes(widgetId)
            canMoveBack: placed.indexOf(widgetId) > 0
            canMoveForward: placed.indexOf(widgetId) >= 0 && placed.indexOf(widgetId) < placed.length - 1
            selected: root.selected === row.index
            onActivated: root.selected = row.index
            onDividerToggled: Settings.setDivider(widgetId, !Settings.dividers.includes(widgetId))
            onZoneChosen: value => Settings.place(widgetId, value)
            onMoved: steps => Settings.move(widgetId, steps)
          }

          ToggleRow {
            visible: row.modelData.kind === "toggles"
            anchors.fill: parent
            label: row.modelData.label
            options: row.modelData.toggles ?? []
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

  ThemedText {
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
