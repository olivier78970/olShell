import Quickshell
import Quickshell.Io
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

    // Sets one numeric setting by name (radius, opacity, spacing, barHeight,
    // barMarginTop, barMarginBottom, barMarginLeft, barMarginRight, panelGap,
    // workspaceCount, launcherResults,
    // barAutoHideDuration, barAutoHideDelay, borderWidth, fontSize, fontWeight,
    // fontLetterSpacing, wallpaperDuration, matugenContrast,
    // matugenLightness, zoomMax, zoomStep, curvedJoinsRadius, blurSize,
    // blurPasses, blurVibrancy, blurContrast, blurBrightness, blurNoise,
    // windowBorderWidth, windowRounding, windowGapsIn, windowGapsOut,
    // windowActiveOpacity, windowInactiveOpacity); out-of-range values are
    // clamped.
    // The yes/no settings (barAutoHide, barAutoHideAnimated, borderOpaque,
    // workspaceCountFromHyprland, clockSeconds, blur, blurXray,
    // windowBorderSame, windowRoundingSame, windowGapsInSame, curvedJoins,
    // curvedJoinsRadiusSame, zoomBlocksInput, fontItalic, fontUnderline,
    // fontOutline, matugenHyprland, matugenZen, matugenAlacritty, matugenGtk,
    // matugenQt, matugenStarship, themeExactApps) take 1 or 0.
    function set(key: string, value: real): void {
      Settings.set(key, value)
    }

    // Puts a bar widget in a zone ("left", "center", "right", or "off" to hide
    // it; the widget ids are launcher, settings, workspaces, activeWindow,
    // clock, wallpaper, theme, screenshot, zoom, shortcuts, tray, cpu, ram,
    // disk, network, connection, bluetooth, volume, notifications, lock, power),
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
    // themeMode, themePill, themeAccent, matugenScheme, matugenSource,
    // matugenAccent, fontCaps, barStyle, barPosition, launcherTab, clockDate,
    // switcherOrientation, switcherScope, weatherUnit,
    // notificationPosition, volumeOsdPosition, lockKeysOsdPosition, and the
    // panels' panelPlacement (every one at once), launcherPlacement, settingsPlacement, shortcutsPlacement,
    // wallpaperPlacement, themePlacement, powerPlacement,
    // notificationActionsPlacement, switcherPlacement, clockPlacement and
    // notificationCenterPlacement; a value
    // not in the list is ignored), for the font family (any installed family,
    // e.g. "DejaVu Sans Mono") and for the custom theme's colors
    // (customBackground, customPill, customBorder, customText, customAccent:
    // a "#rrggbb" color), and for the weather's place (weatherLocation: a
    // place's name, or "" to find it from the internet address).
    function choose(key: string, value: string): void {
      const allowed = key === "fontFamily" ? Qt.fontFamilies().includes(value)
        : key === "weatherLocation" ? true
        : (Settings.colorKeys.includes(key) ? Settings.validColor(value) : Settings.choices[key]?.includes(value))
      if (allowed) Settings.set(key, value)
    }

    function getChoice(key: string): string {
      return String(Settings.get(key))
    }

    // Puts every setting, and the language, back to the built-in defaults and
    // saves them as your defaults too, without asking (the panel's button
    // asks first).
    function factoryReset(): void {
      SettingsPages.factoryResetAll()
    }

    // Puts every setting, and the language, back to your own defaults (the
    // built-in ones for what you have saved none for).
    function reset(): void {
      SettingsPages.resetAll()
    }

    // Saves the current values of a page (appearance, blur, windows, text, bar,
    // layout,
    // widgetSettings, wallpaper, theme, notifications, osd, lock, launcher,
    // panels, switcher, clockPanel or general) as your own defaults.
    function saveDefaults(category: string): void {
      if (SettingsPages.pages.includes(category)) SettingsPages.saveDefaults(category)
    }

    // Puts a category back to your own defaults (source "mine") or to the
    // built-in ones ("factory").
    function restoreDefaults(category: string, source: string): void {
      if (SettingsPages.pages.includes(category) && (source === "mine" || source === "factory")) {
        SettingsPages.restoreDefaults(category, source)
      }
    }
  }

  LazyLoader {
    active: SettingsPanelState.visible || SettingsPanelState.resuming

    SettingsPanel {}
  }
}
