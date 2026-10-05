import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// The settings panel (SettingsPanel.qml), built only while it is open and
// freed once it closes, so it takes no memory while it isn't showing. It
// stays built while it is hidden only for a moment, to pick a color from the
// screen (SettingsPanelState.resuming), so it comes back as it was. Its
// `settings` IPC target lives here, so it answers while the panel isn't
// built.
Scope {
  IpcHandler {
    target: "settings"

    function toggle(): void {
      SettingsPanelState.toggle()
    }

    // The panel's map as JSON, for scripts (the chat AI): its pages, in
    // order ({ id, name }, the name as the panel shows it, "Category > Tab"),
    // each setting's page and name there ({ key: { page, name } }, e.g.
    // "Bar > Position"; each also has its `kind`, "number", "yes/no", "choice",
    // "color", "text" or "list", and a number's `range` [min, max]), and each bar
    // widget's name ({ id: name }), all in the current language; and the values
    // each setting with a list of choices takes ({ key: [values] }).
    function map(): string {
      const pages = []
      const pageNames = {}
      for (const category of SettingsPages.categories) {
        for (const tab of category.tabs ?? [null]) {
          const id = tab ? tab.id : category.id
          pageNames[id] = tab ? category.label + " > " + tab.label : category.label
          pages.push({ id: id, name: pageNames[id] })
        }
      }
      // Each widget picked in the Widgets tab has a page of its own.
      for (const page of SettingsPages.widgetPages) {
        pageNames[page.id] = pageNames.widgets + " > " + page.label
        pages.push({ id: page.id, name: pageNames[page.id] })
      }
      const settings = {}
      const add = (key, page, name) => {
        if (Settings.defaults[key] === undefined || settings[key] !== undefined) return
        const value = Settings.defaults[key]
        const kind = Settings.choices[key] ? "choice"
          : typeof value === "boolean" ? "yes/no"
          : typeof value === "number" ? "number"
          : typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? "color"
          : typeof value === "string" ? "text"
          : "list"
        settings[key] = { page: page, name: name ? pageNames[page] + " > " + name : pageNames[page], kind: kind }
        if (kind === "number" && Settings.limits[key]) settings[key].range = Settings.limits[key]
      }
      for (const row of SettingsPages.rows) {
        add(row.key, row.category, row.label)
        for (const toggle of row.toggles ?? []) add(toggle.key, row.category, toggle.text ? row.label + " > " + toggle.text : row.label)
        for (const key of row.settings ?? []) add(key, row.category, row.label)
        if (row.same) add(row.same, row.category, row.label + " > " + (row.sameText ?? ""))
      }
      // The settings with no row of their own (the bar's layout, the lists
      // edited in rows of their own): named after their page.
      for (const page of pages) {
        for (const key of SettingsPages.keysOf(page.id)) add(key, page.id, "")
      }
      const widgets = {}
      for (const id of Settings.widgetIds) widgets[id] = I18n.tr("settings.widget." + id)
      return JSON.stringify({ pages: pages, settings: settings, widgets: widgets, choices: Settings.choices })
    }

    // Opens the panel on a page: a category without tabs or a tab (the
    // names resetPage takes, e.g. "wallpaper", "launcher", "panels" for
    // the Panels category's Placement tab, "blur"), or a category with tabs
    // by its id, on its first tab, or a widget's page (widgetCpu...), on the
    // Widgets tab picking that widget. An unknown page opens it where it was.
    function open(page: string): void {
      // A widget's page opens the Widgets tab on that widget.
      const widget = SettingsPages.widgetPages.some(candidate => candidate.id === page)
      if (widget) SettingsPanelState.widgetPage = page
      const target = widget ? "widgets" : page
      const category = SettingsPages.categories.findIndex(category => category.id === target || (category.tabs ?? []).some(tab => tab.id === target))
      if (category >= 0) {
        SettingsPanelState.category = category
        SettingsPanelState.tab = Math.max(0, (SettingsPages.categories[category].tabs ?? []).findIndex(tab => tab.id === target))
      }
      if (!SettingsPanelState.visible) SettingsPanelState.toggle()
    }

    // Sets one numeric setting by name (radius, opacity, spacing, barHeight,
    // barMarginTop, barMarginBottom, barMarginLeft, barMarginRight, panelGap,
    // workspaceCount, launcherResults, launcherHistory, chatAiHistory,
    // barAutoHideDelay, animationDuration, hyprlandAnimationDuration, borderWidth,
    // fontSize, fontWeight,
    // fontLetterSpacing, wallpaperDuration, wallpaperSideCount, themeSideCount,
    // matugenContrast,
    // matugenLightness, zoomMax, zoomStep, curvedJoinsRadius, blurSize,
    // blurPasses, blurVibrancy, blurContrast, blurBrightness, blurNoise,
    // windowBorderWidth, windowRounding, windowGapsIn, windowGapsOut,
    // windowActiveOpacity, windowInactiveOpacity, osdMargin, volumeOsdMargin,
    // lockKeysOsdMargin); out-of-range values are
    // clamped.
    // The yes/no settings (barAutoHide, animations, hyprlandAnimations,
    // hyprlandAnimationSame,
    // borderOpaque,
    // workspaceCountFromHyprland, clockSeconds, cpuActionTerminal,
    // ramActionTerminal, diskActionTerminal, networkActionTerminal,
    // connectionActionTerminal, bluetoothActionTerminal, cpuActionFloating,
    // ramActionFloating, diskActionFloating, networkActionFloating,
    // connectionActionFloating, bluetoothActionFloating, blur, blurXray,
    // windowBorderSame, windowBorderColors, windowRoundingSame, windowGapsInSame, windowActiveOpacitySame,
    // windowInactiveOpacitySame, volumeOsdSame, lockKeysOsdSame,
    // curvedJoins,
    // curvedJoinsRadiusSame, zoomBlocksInput, fontItalic, fontUnderline,
    // fontOutline, matugenHyprland, matugenZen, matugenAlacritty, matugenGtk,
    // matugenQt, matugenStarship, themeExactApps, lockStayAwakeFullscreen,
    // chatAiListDir, chatAiFindFiles, chatAiSearchText, chatAiReadFile,
    // chatAiWebSearch, chatAiWebFetch, chatAiShellDocs, chatAiShellIpc,
    // chatAiShowUsage, chatAiShowHint, chatAiShowAccess) take
    // 1 or 0.
    function set(key: string, value: real): void {
      Settings.set(key, value)
    }

    // Puts a bar widget in a zone ("left", "center", "right", or "off" to hide
    // it; the widget ids are launcher, settings, workspaces, activeWindow,
    // clock, wallpaper, theme, screenshot, zoom, shortcuts, tray, cpu, ram,
    // disk, network, connection, bluetooth, volume, notifications, lock, power, chatAi,
    // webApps),
    // at the end of it, or `position` places from its start when not negative.
    function place(widget: string, zone: string, position: int): void {
      Settings.place(widget, zone, position < 0 ? undefined : position)
    }

    // Enables a bar widget (1: it is loaded again, back where it was on the bar)
    // or disables it (0: off the bar, and its feature, with its panel, service,
    // OSD and IPC calls, unloaded, so those calls no longer exist). The settings
    // button can't be disabled; placing a disabled widget enables it.
    function widgetEnabled(widget: string, on: int): void {
      Settings.setWidgetEnabled(widget, on !== 0)
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

    // Sets the mode of the group that widget is in: "on", "hover" (shown only
    // while its pill is hovered) or "off". A group starts at the first widget
    // of a pill and at each widget with a divider before it.
    function group(widget: string, mode: string): void {
      Settings.setGroupMode(Settings.leaderOf(widget), mode)
    }

    // Moves the group that widget is in `steps` places later (negative:
    // earlier) in its pill.
    function moveGroup(widget: string, steps: int): void {
      Settings.moveGroup(Settings.leaderOf(widget), steps)
    }

    // The bar's layout as JSON: { "left": [ids], "center": [ids], "right":
    // [ids], "dividers": [the ids with a divider before them], "collapsed":
    // [the widgets starting a group shown only on hover], "off": [the widgets
    // starting a group that is off], "disabled": [the widgets that are
    // disabled] }.
    function layout(): string {
      return JSON.stringify(Object.assign({}, Settings.layout, { dividers: Settings.dividers, collapsed: Settings.collapsed, off: Settings.hiddenGroups, disabled: Settings.disabledWidgets }))
    }

    function get(key: string): real {
      return Settings.get(key)
    }

    // The launcher's search engines as JSON, in order: [{ "name", "url",
    // "on" }, ...], with { "browser": true, "on" } for the default browser's
    // own. The calls below take an engine's place in that list, from 0.
    function engines(): string {
      return JSON.stringify(Settings.launcherEngines)
    }

    // The clock panel's clocks tab's places, as JSON: [{ name, zone }].
    function worldClocks(): string {
      return JSON.stringify(Settings.worldClocks)
    }

    // Looks a place up by name and adds it, with its time zone.
    function addWorldClock(name: string): void {
      WorldClock.add(name)
    }

    // Takes place `index` (from 0) out of the list, or moves it `steps`
    // places later (negative: earlier).
    function removeWorldClock(index: int): void {
      Settings.removeWorldClock(index)
    }

    function moveWorldClock(index: int, steps: int): void {
      Settings.moveWorldClock(index, steps)
    }

    // Adds an engine at the end (the address with %s where the search goes);
    // ignored without a name or %s.
    function addEngine(name: string, url: string): void {
      Settings.addEngine(name, url)
    }

    // Takes an engine out of the list (not the browser's).
    function removeEngine(index: int): void {
      Settings.removeEngine(index)
    }

    // Moves an engine `steps` places later (negative: earlier).
    function moveEngine(index: int, steps: int): void {
      Settings.moveEngine(index, steps)
    }

    // Offers an engine in the launcher (1) or not (0).
    function engineOn(index: int, on: int): void {
      Settings.setEngine(index, { on: on !== 0 })
    }

    // The web apps as JSON, in order: [{ "name", "url", "on" }]. The calls
    // below take a web app's place in that list, from 0.
    function webApps(): string {
      return JSON.stringify(Settings.webApps)
    }

    // Adds a web app at the end (a name and a web address); ignored without
    // either.
    function addWebApp(name: string, url: string): void {
      Settings.addWebApp(name, url)
    }

    function removeWebApp(index: int): void {
      Settings.removeWebApp(index)
    }

    // Moves a web app `steps` places later (negative: earlier).
    function moveWebApp(index: int, steps: int): void {
      Settings.moveWebApp(index, steps)
    }

    // Offers a web app in the bar widget's menu (1) or not (0).
    function webAppOn(index: int, on: int): void {
      Settings.setWebApp(index, { on: on !== 0 })
    }

    // The apps with an opacity of their own as JSON: [{ "class", "active",
    // "inactive" }] (Hyprland's window class, the opacities from 0.1 to 1).
    function appOpacities(): string {
      return JSON.stringify(Settings.appOpacities)
    }

    // Gives the app of window class `appClass` its own opacities, focused and
    // not (added if it has none yet).
    function setAppOpacity(appClass: string, active: real, inactive: real): void {
      Settings.addAppOpacity(appClass)
      const index = Settings.appOpacities.findIndex(app => app.class === appClass)
      if (index >= 0) Settings.setAppOpacity(index, { active: active, inactive: inactive })
    }

    // Has the app of window class `appClass` follow the windows' general
    // opacity (1) or keep its own (0), when focused and when not.
    function linkAppOpacity(appClass: string, active: int, inactive: int): void {
      const index = Settings.appOpacities.findIndex(app => app.class === appClass)
      if (index >= 0) Settings.setAppOpacity(index, { activeSame: active !== 0, inactiveSame: inactive !== 0 })
    }

    // Puts the app of window class `appClass` back on the general opacities.
    function removeAppOpacity(appClass: string): void {
      const index = Settings.appOpacities.findIndex(app => app.class === appClass)
      if (index >= 0) Settings.removeAppOpacity(index)
    }

    // The apps added to the themed apps as JSON, in order: [{ "name",
    // "template", "output", "hook", "on" }]. The calls below take an app's
    // place in that list, from 0.
    function matugenApps(): string {
      return JSON.stringify(Settings.matugenApps)
    }

    // Adds an app: its name, its matugen template, the file matugen writes
    // from it, and a shell command run after ("" for none).
    function addMatugenApp(name: string, template: string, output: string, hook: string): void {
      if (name.trim().length === 0) return
      Settings.addMatugenApp(name.trim())
      Settings.setMatugenApp(Settings.matugenApps.length - 1, { template: template.trim(), output: output.trim(), hook: hook.trim() })
    }

    // Takes an added app out of the list.
    function removeMatugenApp(index: int): void {
      Settings.removeMatugenApp(index)
    }

    // Has matugen color an added app (1) or not (0).
    function matugenAppOn(index: int, on: int): void {
      Settings.setMatugenApp(index, { on: on !== 0 })
    }

    // The same for a setting with a fixed list of choices (wallpaperTransition,
    // wallpaperCarousel, themeCarousel,
    // themeMode, themePill, themeAccent, matugenScheme, matugenSource,
    // matugenAccent, fontCaps, barStyle, barPosition, hyprlandWindowStyle,
    // hyprlandWorkspaceStyle, launcherTab, clockDate, cpuLayout, ramLayout, diskLayout,
    // volumeLayout, networkLayout, activeWindowLayout (auto, vertical or horizontal),
    // switcherOrientation, switcherScope, weatherUnit,
    // notificationPosition, osdPosition, volumeOsdPosition, lockKeysOsdPosition, and the
    // panels' panelPlacement (every one at once), launcherPlacement, settingsPlacement, shortcutsPlacement,
    // wallpaperPlacement, themePlacement, powerPlacement,
    // notificationActionsPlacement, switcherPlacement, clockPlacement,
    // notificationCenterPlacement and chatAiPlacement; a value
    // not in the list is ignored), for the font family (any installed family,
    // e.g. "DejaVu Sans Mono") and for the custom theme's colors
    // (customBackground, customPill, customBorder, customText, customAccent:
    // a "#rrggbb" color), for the chat AI's default provider
    // (chatAiDefaultProvider: a provider's id, e.g. "anthropic", or "" for the
    // first one that can be asked), for the weather's place (weatherLocation: a
    // place's name, or "" to find it from the internet address), and for the
    // command opening a web app (webAppCommand: a program and its arguments,
    // %s for the address; "" for the default), and for the command a click on
    // a bar widget runs (cpuAction, ramAction, diskAction, networkAction,
    // connectionAction, bluetoothAction: a program and its arguments; "" for
    // nothing).
    function choose(key: string, value: string): void {
      const allowed = key === "fontFamily" ? Qt.fontFamilies().includes(value)
        : key === "weatherLocation" || key === "webAppCommand" || WidgetActions.ids.some(id => key === id + "Action") ? true
        : key === "chatAiDefaultProvider" ? (value === "" || ChatAi.known.some(provider => provider.id === value))
        : (Settings.colorKeys.includes(key) ? Settings.validColor(value) : Settings.choices[key]?.includes(value))
      if (allowed) Settings.set(key, value)
    }

    function getChoice(key: string): string {
      return String(Settings.get(key))
    }

    // Puts every setting, the language and the theme to the built-in ones
    // (the Factory profile), without asking.
    function factoryReset(): void {
      SettingsPages.factoryResetAll()
    }

    // Puts every setting, the language and the theme back to those of the
    // current profile (`profiles list` names it).
    function reset(): void {
      SettingsPages.resetAll()
    }

    // Puts a page (appearance, blur, windows, text, bar, layout,
    // widgetWorkspaces, widgetActiveWindow, widgetClock, widgetCpu,
    // widgetRam, widgetDisk, widgetNetwork, widgetConnection,
    // widgetBluetooth, widgetVolume, widgetZoom,
    // wallpaper, theme, notifications, osd, volumeOsd,
    // lockKeysOsd, lock, launcher,
    // panels, switcher, clockPanel or general) back to the settings of the
    // current profile.
    function resetPage(category: string): void {
      if (SettingsPages.pages.includes(category)) SettingsPages.resetPage(category)
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: SettingsPanelState.visible || SettingsPanelState.resuming
  }

  LazyLoader {
    active: linger.active

    SettingsPanel {}
  }
}
