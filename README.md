# olShell

olShell is a [Quickshell](https://quickshell.org) shell for Hyprland: a top bar replicated on every monitor, a btop window (click the CPU, RAM or network-speed widget to see just that part), pavucontrol for the audio mixer (click the volume widget), a gdu disk usage window (click the disk widget), an application launcher, a wallpaper picker and a theme picker (automatic from the wallpaper, or one of 10 fixed themes), a clock popup with an agenda and performance figures, live CPU / RAM / network-speed widgets, a volume OSD, a screenshot button, a notification center with pop-ups, a Caps Lock / Num Lock OSD and a lock screen (by idle timer or a button), a power panel with confirmation, all in English, French or Spanish.

## Requirements

- [Quickshell](https://quickshell.org) and Hyprland (workspaces and logout use the Hyprland integration)
- [matugen](https://github.com/InioX/matugen) and [awww](https://codeberg.org/LGFae/awww) for the wallpaper picker (awww is the wallpaper daemon; the shell starts it when it isn't running)
- [`pavucontrol`](https://freedesktop.org/software/pulseaudio/pavucontrol/) for the audio mixer (volume click)
- [`gdu`](https://github.com/dundee/gdu) for the disk usage window (click on the disk widget)
- PipeWire (volume)
- `grim` and `slurp` for the screenshot button, and optionally `wl-clipboard` (`wl-copy`, to copy the picture), `libnotify` (`notify-send`, to announce it) and [`satty`](https://github.com/gabm/satty) (to annotate it)
- `btop` for the btop window, and a terminal (`alacritty` by default, configurable in [config/Apps.qml](config/Apps.qml)) for these windows
- a Nerd Font, used for text and icons: "0xProto Nerd Font" by default, changeable in the settings (see [Settings](#settings))
- optionally [Zen browser](https://zen-browser.app), whose interface matugen can color with the shell's palette (see [Zen browser](#zen-browser))

## Structure

```
.
├── shell.qml                 # Shell root — wires modules together
├── config/
│   ├── Theme.qml             # Sizes, font, corner radius, border width and colors shared by every widget
│   ├── GeneratedColors.qml   # Active palette: selected theme, or matugen's GeneratedColors.json
│   ├── ThemePresets.qml      # The selectable themes ("auto" + 10 fixed palettes)
│   ├── ThemeState.qml        # Selected theme and last wallpaper, saved in ThemeState.json
│   ├── Settings.qml          # Adjustable values (look-and-feel, wallpaper transition), saved in Settings.json (Theme reads them), and the user's own defaults in UserDefaults.json
│   ├── Defaults.qml          # The built-in default of every setting (read-only: nothing writes to it)
│   ├── SettingsPanelState.qml   # Shared visibility of the settings panel
│   ├── I18n.qml, Translations.qml   # Localization: language choice + lookup, and the English / French / Spanish texts
│   ├── ThemePanelState.qml   # Shared visibility of the theme panel
│   ├── LauncherState.qml     # Shared visibility of the launcher
│   ├── ShortcutsPanelState.qml # Shared visibility of the keyboard shortcuts panel
│   ├── NotificationCenterState.qml   # Shared visibility of the notification center
│   ├── Paths.qml             # Wallpaper, matugen and palette locations
│   ├── Apps.qml              # Commands launched by clicking widgets
│   ├── PowerMenuState.qml    # Pending power action + the commands that run it
│   ├── PowerPanelState.qml   # Shared visibility of the power panel
│   └── WallpaperPanelState.qml   # Shared visibility of the wallpaper panel
├── services/
│   ├── Audio.qml             # Default output volume/mute + `volume` IPC target
│   ├── Screenshot.qml        # Takes screenshots (mode remembered) + `screenshot` IPC target
│   ├── Lock.qml              # Lock state, password check (PAM) + `lock` IPC target
│   ├── Notifications.qml     # The notification server (history, do not disturb) + `notifications` IPC target
│   ├── LockKeys.qml          # Caps Lock / Num Lock state, from scripts/lock-keys-watch.py
│   ├── DesktopLocale.qml     # Application names/descriptions in the shell's language, read from the .desktop files
│   ├── TuiWindow.qml         # A TUI app in a floating, themed terminal window that opens/closes like a panel
│   ├── Btop.qml              # The btop window (toggle + `btop` IPC target)
│   ├── Gdu.qml               # The gdu window (toggle + `gdu` IPC target)
│   ├── Matugen.qml           # Runs matugen when a wallpaper is applied or a theme is selected
│   └── SystemStats.qml       # CPU, RAM, network speed and disks, with short histories (polled once, not per monitor)
├── components/               # Generic building blocks shared by the widgets (import qs.components)
│   ├── ThemedText.qml        # Text in the shell's font and color
│   ├── Pill.qml, Separator.qml, IconButton.qml, TabBar.qml, PowerMenuOption.qml   # Bar pill, divider and buttons
│   ├── PopupMenu.qml, HoverPopup.qml   # Popup windows: a menu, and one opened by hovering
│   ├── ModalPanel.qml        # Base of the full-screen panels: backdrop, frame, keyboard focus
│   ├── CarouselPanel.qml, CarouselCard.qml   # Base of the two pickers (wallpapers, themes)
│   ├── RingGauge.qml, Sparkline.qml   # Gauge and area chart
│   ├── PowerConfirmDialog.qml   # Confirmation shown after picking a power action
│   └── SettingSlider.qml, ChoiceRow.qml, DropdownRow.qml, ToggleRow.qml, WidgetRow.qml, GroupRow.qml, PathRow.qml, DefaultsRow.qml, PositionIcon.qml   # Rows of the settings panel
├── modules/                  # One directory per feature (import qs.modules.<Name>)
│   ├── Bar/                  # The top bar
│   │   ├── Bar.qml           # Top bar, one per screen: three WidgetZones
│   │   ├── WidgetZone.qml, WidgetSlot.qml   # A pill filled from Settings.layout, and one widget in it with its divider
│   │   ├── BarWidgets.qml    # The widgets by id (a singleton)
│   │   └── Widgets/          # What sits in the bar (import qs.modules.Bar.Widgets)
│   │       ├── Workspaces, ActiveWindow, Clock, WallpaperTrigger, ThemeTrigger, LauncherTrigger, LanguageTrigger, SettingsTrigger
│   │       ├── ClockPanel.qml, AgendaTab.qml, PerformanceTab.qml   # Clock popup: tab bar + pages
│   │       ├── Tray, TrayItem, TrayMenuItem
│   │       ├── CpuUsage, RamUsage, DiskUsage, NetworkSpeed, Volume, NotificationBell, LockButton
│   │       └── PowerTrigger
│   ├── Launcher/LauncherPanel.qml     # Application launcher (ModalPanel + desktop entries)
│   ├── Shortcuts/ShortcutsPanel.qml   # The Hyprland config's shortcuts, grouped and searchable
│   ├── Notifications/        # NotificationPopups (the pop-ups), NotificationCenter (the history panel), NotificationCard
│   ├── Lock/LockScreen.qml   # The lock screen (session lock) + the idle timer
│   ├── Power/PowerPanel.qml  # The power panel: log out, restart, shut down (ModalPanel)
│   ├── Osd/                  # Bottom-of-screen popups
│   │   ├── VolumeOsd.qml     # Volume
│   │   └── LockKeysOsd.qml   # Caps Lock / Num Lock
│   ├── Settings/SettingsPanel.qml     # Settings panel (built from SettingSlider, ChoiceRow, DropdownRow, ToggleRow and WidgetRow)
│   ├── Theme/ThemePanel.qml           # Theme picker (CarouselPanel + ThemeState)
│   └── Wallpapers/WallpaperPanel.qml  # Wallpaper picker (CarouselPanel + awww/matugen)
├── scripts/apply-wallpaper.py   # Shows an image as the wallpaper with awww, starting its daemon if needed (used by the wallpaper panel)
├── scripts/screenshot.py        # Takes a screenshot (screen, rectangle or window), saves and copies it (used by services/Screenshot.qml)
├── scripts/lock-keys-watch.py   # Prints the Caps/Num Lock state on every change (used by services/LockKeys.qml)
├── scripts/list-shortcuts.py # Reads the shortcuts from the Hyprland config, as JSON (for the shortcuts panel)
├── scripts/tui-launch.py     # Themes and starts btop or gdu in a terminal (used by services/TuiWindow.qml)
└── matugen/                  # Everything matugen: its config and every template it fills
    ├── quickshell.toml       # The config: the shell's palette and the other apps' colors (Hyprland, Zen, alacritty, GTK, starship)
    ├── quickshell-theme.json.template   # Template of the shell's palette (written to config/GeneratedColors.json)
    ├── hyprland-theme.lua.template      # Template of Hyprland's colors (~/.config/hypr/colors.lua)
    ├── zen-theme.css.template           # Template coloring Zen browser
    ├── alacritty-theme.toml.template    # Template coloring alacritty
    ├── gtk-theme.css.template           # Template of the GTK named colors (libadwaita, and the olShell theme's)
    ├── gtk3-theme-index.css.template    # The olShell GTK theme's GTK3 part (adw-gtk3-dark + the colors)
    ├── gtk4-theme-index.css.template    # The olShell GTK theme's GTK4 part, for plain GTK4 apps
    └── starship-theme.toml.template     # Template of the starship prompt (~/.config/starship/starship.toml)
```

Quickshell auto-generates QML modules for each subdirectory, so files are referenced with `qs.<path>` imports (e.g. `import qs.config`, `import qs.services`, `import qs.components`, `import qs.modules.Bar.Widgets`, `import qs.modules.Settings`) instead of relative paths.

## Running

```sh
quickshell -p .
```

Or symlink/copy this directory to `~/.config/quickshell/<name>` and run:

```sh
quickshell -c <name>
```

## Settings

The gear icon in the left part of the bar, or `quickshell -p . ipc call settings toggle` (bind it to a key), opens a settings panel where the look of the shell can be adjusted live; every change applies immediately and is remembered in `config/Settings.json` (git-ignored; the language is remembered as before). The settings, with their range:

| Category | Setting | Range | Default |
|---|---|---|---|
| Appearance | Widget radius | 0 – 30 px | 5 |
| Appearance | Widget opacity | 0 – 100 % (fades pill backgrounds only, not their text/icons; the bar's pills only in the Individual widgets style) | 90 % |
| Appearance | Widget spacing | 0 – 40 px | 15 |
| Appearance | Border width | 0 – 6 px | 2 |
| Text | Font size | 10 – 32 px | 18 |
| Text | Font weight | Thin / Extra light / Light / Normal / Medium / Semi bold / Bold / Extra bold / Black (100 – 900) | Normal |
| Text | Letter spacing | -2 – 6 px | 0 |
| Text | Capitalization | As typed / UPPERCASE / lowercase / Small caps | As typed |
| Text | Font style | Italic, underline, outline (each on / off) | all off |
| Text | Font | the installed Nerd Font families | 0xProto Nerd Font |
| Top bar | Auto-hide the bar | on / off (check box); tucks the bar away until the pointer reaches the edge of the screen it's anchored to | off |
| Top bar | Animate showing/hiding it | on / off (check box) | on |
| Top bar | Animation duration | 0 – 600 ms (only while animating it) | 150 ms |
| Top bar | Hide delay | 0 – 3000 ms; how long the pointer has to be away before it tucks away again | 500 ms |
| Top bar | Bar position | Top / Bottom | Top |
| Top bar | Top bar height | 28 – 72 px | 40 |
| Top bar | Top bar top margin | 0 – 100 px | 5 |
| Top bar | Top bar bottom margin | 0 – 100 px | 0 |
| Top bar | Top bar left margin | 0 – 300 px | 5 |
| Top bar | Top bar right margin | 0 – 300 px | 5 |
| Top bar | Bar style | Individual widgets (each pill has its own background) / Full bar (one background behind every widget, the pills' own go transparent) | Individual widgets |
| Top bar | Top bar opacity | 0 – 100 % (only in the Full bar style) | 60 % |
| Widgets | Each bar widget | on / off (check box), Left / Center / Right, and its place there | the original layout |
| Wallpaper | Wallpaper transition | Fade / None / From left / From right / From top / From bottom / Wipe / Wave / Grow / From center / To center / From anywhere / Random | Fade |
| Wallpaper | Transition duration | 0.5 – 10 s | 2 s |
| Notifications | Pop-up duration | 2 – 30 s | 6 s |
| Notifications | Pop-ups at once | 1 – 8 | 4 |
| Notifications | Notification position (a list of small screens with a block where the pop-ups go, and the name) | Top right / Top center / Top left / Right center / Left center / Bottom right / Bottom center / Bottom left | Top right |
| Notifications | Do not disturb | check box | off |
| General | Language | Automatic / English / Français / Español | Automatic |
| General | Screenshot folder | an absolute path (`~` is your home folder), typed in | `~/Pictures/Screenshots` |

**The bar's layout.** The widgets category has a row per bar widget (launcher, settings button, workspaces, window title, clock, wallpaper, theme and screenshot buttons, tray, CPU, RAM, disk, network, volume, notifications, lock, power) with a check box to put it on the bar or take it off (hidden; turned on again it goes back where it was, else to its default pill), and buttons to put it in the **Left**, **Center** or **Right** pill (which also turns it on), and ‹ › arrows to move it earlier or later in its pill. Putting a widget in a pill adds it at the end. The rows are listed as the widgets are on the bar: a section at a time (**Left**, **Center**, **Right**, then the ones that are **Off**), each with its name above it, and each **group** (see below) drawn as a block, with a bar on its left, so what the dividers separate is visible; a row that changes section moves to its new place in the list, and the selection follows it. Each row also has a **│** button: the divider drawn before that widget (lit when on; **D** on the keys). A divider only shows when its widget does and something shown comes before it in the pill, so there is none at the start of a pill or for a widget with nothing to show (the window title when no window is open), and it goes with its widget when that is moved; a pill with nothing left in it disappears. By default there is one before every widget except the launcher, the settings button, the clock and the tray, which is how the bar looked before this was adjustable. The widgets between two dividers form a **group**, which starts at the first widget of a pill and at each widget with a divider before it. Each group is headed by a **Group** row with a check box (right after the name, in the same column as the widgets' check boxes), an **On hover** button and ‹ › arrows. Ticked means the group is shown; unticked, it is off and never shown (its widgets stay in the group, so it can be turned on again). **On hover** lit means that, while it is on, it is shown only while the pointer is over its pill: its widgets slide open when you hover the pill and shut again half a second after you leave it (the group of a widget whose popup is showing, such as the clock, stays open until the popup closes, so the popup keeps its anchor; the other groups shut as usual). The arrows move the whole group earlier or later in its pill, past whole groups (the dividers follow, so the groups stay what they were). A pill whose groups are all on hover keeps a small dots icon to hover, and a pill whose groups are all off is not drawn. Dividers are drawn against what is showing, so hiding a group also drops the divider it would have had. The settings button can go anywhere but off, so this panel stays reachable by clicking. The layout is saved as three lists (`barLeft`, `barCenter`, `barRight`), the widgets with a divider before them (`barDividers`) and the widgets starting a group shown only on hover (`barCollapsed`) or off (`barGroupsOff`) in `config/Settings.json`; a widget listed twice or unknown is ignored. On the keys, **←/→** on a widget row change its pill (Off, Left, Center, Right) and **Shift+←/→** move it within the pill; on a group row, **←/→** move between the check box and the button, **Enter** or **Space** switches the one the keys are on, and **Shift+←/→** move the group.

Bar position picks which edge of the screen the bar is anchored to. Either way, the top and bottom margins keep their own meaning: whichever is on the side the bar is anchored to is the gap between the bar and that edge, and the other becomes extra room kept free on the far side of the bar (the bar reserves its height plus this much, so windows start that much further away), on top of your compositor's own gaps; at 0 the layout is what it was without the setting. Popups that open from the bar's own widgets (the clock, the tray, a widget's tooltip) open upward instead of downward when the bar is at the bottom, so they always open toward the middle of the screen. The text settings apply to all text and icons in the shell: the weight is what the font offers (a font without that weight uses the nearest it has), the outline is drawn in the accent color, and letter spacing and capitalization change the width of the text (so the bar's contents move). The settings are grouped in categories, shown as a column of buttons on the left of the panel, each an icon with its name (appearance, text, top bar, widgets, wallpaper, general); click one to show its settings, whose name is the panel's heading.

The panel is 920 px wide, or wider (within the screen) when the widest row of the category needs it, as with the longer French names, so it follows the language, the font size and the font. A category with more rows than fit (the widgets, mostly) scrolls: with the wheel, or by moving the selection with the keys, which keeps it in view. Click or drag a slider (the font, the wallpaper transition and the pop-up position each open a list: click an entry to pick it, or scroll for more; the fonts are drawn in their own font, the positions with a small screen icon), or use the keys: **↑/↓** select a row, **←/→** adjust it (**Shift** for bigger steps), **Page Up/Page Down** switch category, **Enter** opens the list of a font, transition or position row (then **↑/↓**, **Page Up/Page Down**, **Home/End** move in it, **Enter** picks, **Escape** closes just the list); on the font style row, **←/→** move between the buttons and **Enter** (or **Space**) switches one, **Escape** closes. **Reset** (top right, next to the category's name) puts that category back to your own defaults, or to the built-in ones for any setting you saved none for. **Defaults:** the last row of each category has two buttons: **Save as my defaults** remembers the category's current values as your own defaults (in `config/UserDefaults.json`, git-ignored; for the widgets category that is the whole bar layout, and for General the language too), and **Factory defaults** puts the category back to the built-in ones, whatever you saved, and saves them as your defaults too, so Reset then does the same: it first asks for a confirmation in the row itself (**Confirm** or **Cancel**; Cancel is the one the keys are on, and Escape cancels). The built-in defaults are in [config/Defaults.qml](config/Defaults.qml), which nothing writes to, so they are always there to go back to. On the keys, **←/→** move to a button and **Enter** presses it. The General category also has an **All categories** row with a **Factory defaults** button that does the same for every category and the language: it asks first (**Confirm** or **Cancel** in the row; Escape cancels), then puts everything back to the built-in values, saves them as your defaults and forgets where turned-off widgets were. (`settings factoryReset` does it from a script, without asking.) Neither the font size nor the icons (tray and active window) depend on the bar height, so a large font in a low bar can overflow the pills, and a very tall bar with big margins can make the bar's three groups collide.

From a script: `quickshell -p . ipc call settings set <key> <value>` (keys: `radius`, `opacity`, `spacing`, `barHeight`, `barMarginTop`, `barMarginBottom`, `barMarginLeft`, `barMarginRight`, `panelGap`, `workspaceCount`, `barOpacity`, `barAutoHideDuration`, `barAutoHideDelay`, `borderWidth`, `fontSize`, `fontWeight` (100 to 900, rounded to hundreds), `fontLetterSpacing`, `wallpaperDuration`, `zoomMax`, `zoomStep`, and `barAutoHide`, `barAutoHideAnimated`, `fontItalic`, `fontUnderline`, `fontOutline`, `zoomBlocksInput` with 1 or 0; out-of-range values are clamped), `settings choose <key> <value>` for the ones with a list of choices (`wallpaperTransition`, `fontCaps` (`none`, `upper`, `lower`, `small`), `barStyle` (`widgets`, `full`) and `barPosition` (`top`, `bottom`)), where a value not in the list is ignored, and `fontFamily`, which takes any installed font family, e.g. `settings choose fontFamily "DejaVu Sans Mono"`; the panel's list only has the Nerd Font families, since the icons are Nerd Font glyphs; Qt only reads the installed fonts when the shell starts, so restart the shell after installing or removing one), `settings place <widget> <zone> [position]` (zone: `left`, `center`, `right` or `off`; widgets: `launcher`, `settings`, `workspaces`, `activeWindow`, `clock`, `wallpaper`, `theme`, `screenshot`, `zoom`, `tray`, `cpu`, `ram`, `disk`, `network`, `volume`, `notifications`, `lock`, `power`; position from 0, or -1 for the end), `settings widgetShown <widget> <1|0>` (put a widget on the bar, back where it was, or take it off), `settings move <widget> <steps>` (negative: earlier), `settings divider <widget> <1|0>` (the divider before a widget), `settings group <widget> <on|hover|off>` (the mode of the group that widget starts), `settings moveGroup <widget> <steps>` (move that group earlier or later in its pill), `settings layout` (prints the layout and dividers as JSON), `settings get <key>`, `settings getChoice <key>` (for the font family and capitalization too) and `settings reset` (every category, to your defaults), `settings saveDefaults <category>` (save a category's current values as your defaults) and `settings restoreDefaults <category> <mine|factory>` (categories: `appearance`, `text`, `bar`, `widgets`, `workspaces`, `zoom`, `wallpaper`, `notifications`, `general`). The transition and its duration apply the next time a wallpaper is applied (they are the `awww img` `--transition-type` and `--transition-duration`), including when the shell restores the last one at startup.

Values live in [config/Settings.qml](config/Settings.qml), which `Theme` reads, so to make another value adjustable add it there (its built-in default in [config/Defaults.qml](config/Defaults.qml), limits, property), point `Theme` at it, and add a row (with its `category`) in [modules/Settings/SettingsPanel.qml](modules/Settings/SettingsPanel.qml) and its label in [config/Translations.qml](config/Translations.qml).

## Localization

The shell speaks **English**, **French** and **Spanish**. By default it follows the system language (`LC_ALL`, `LC_MESSAGES` or `LANG`; English if that isn't one of them). The language can be chosen in the settings panel (General), and the choice is remembered in `config/LocaleState.json` (git-ignored). It can also be set from a key binding or a script (`toggle` goes to the next language, English → French → Spanish):

```sh
quickshell -p . ipc call language set es      # or en, fr, or auto to follow the system again
quickshell -p . ipc call language toggle
quickshell -p . ipc call language get
```

Everything is switched at once: texts, dates and month/day names, decimal separators, and units (Gio / GiB). The week still starts on Monday in both.

The launcher's application names, descriptions and keywords follow the shell's language too, not the system's: every `.desktop` file carries all its translations (`Comment[fr]=...`), so [services/DesktopLocale.qml](services/DesktopLocale.qml) reads them straight from the files (the user's and system's `applications` directories, in priority order) and picks the best one for the current language (`language_COUNTRY`, then `language`, then the untranslated text), instead of the single language Quickshell reads at startup. Searching matches the translated name and keywords as well as the untranslated name ("files" still finds Fichiers). The files are read again each time the launcher opens; an application with no readable file falls back to Quickshell's own text.

The texts are in [config/Translations.qml](config/Translations.qml), one dictionary per language with dotted keys (`power.logout`); [config/I18n.qml](config/I18n.qml) looks them up with `I18n.tr("key", args...)`, replacing `{0}`, `{1}`... and choosing between `one` / `other` forms for counts. A key missing from a language falls back to English, then shows the key itself. To add a language: add a dictionary with the same keys as `en` (including `format.locale`, `format.decimal`, `format.units`, `format.dateTime`) and list its code in `I18n.supported`. Use `I18n.tr` for any new visible text rather than a literal.

## btop

Clicking the CPU, RAM or network-speed widget opens btop in a terminal window showing only that widget's box (its **cpu**, **mem** or **net** box), and clicking again closes it. The same from a key binding: `quickshell -p . ipc call btop cpu` (or `memory`, `network`); `quickshell -p . ipc call btop toggle` opens the full btop, with the boxes of your own configuration, which no widget does. A single-box window is smaller (50% × 50% of the monitor; `btopBoxWidth` and `btopBoxHeight` in [config/Apps.qml](config/Apps.qml)); the full one is 85% × 90%. The box is chosen by setting `shown_boxes` in the copy of your `btop.conf` described below (for the memory box, `show_disks` is turned off too, since btop would draw the disks inside it; see `boxSettings` in [services/Btop.qml](services/Btop.qml)), so your own configuration and its layout are not touched. There is one btop window, so a click on another widget while it is open closes it instead of switching to that widget's box. [services/TuiWindow.qml](services/TuiWindow.qml) (shared with the gdu window, below) launches the terminal through Hyprland with launch-time window rules (floating, centered, sized to a fraction of the focused monitor), so nothing needs adding to your Hyprland config. The window has its own class (`quickshell-btop`), which is how the toggle finds it to close it, even after a shell reload.

The window is themed with the shell's current colors: [scripts/tui-launch.py](scripts/tui-launch.py) generates a btop theme from the palette (background, text, accent, outline) each time it opens, plus a copy of your `btop.conf` that selects it, in `$XDG_RUNTIME_DIR/quickshell-btop/`, and starts the terminal with matching colors (for alacritty). Your own `~/.config/btop/btop.conf` is never modified; settings you change inside this btop are saved to the copy, and it picks up the theme that's active when it's opened.

It is a real terminal window, so btop works completely (mouse, copy/paste, resizing) but it's an ordinary window: no dimmed backdrop, and clicking elsewhere or pressing Escape doesn't close it. The terminal and size (as fractions of the monitor, 85% × 90% by default) are in [config/Apps.qml](config/Apps.qml) (`btopTerminal`, `btopWidth`, `btopHeight`); another terminal works too, but only alacritty gets the colors applied (btop itself is themed either way).

## Audio mixer

Clicking the volume widget opens [pavucontrol](https://freedesktop.org/software/pulseaudio/pavucontrol/), and clicking again closes it (whichever way it was opened). It's an ordinary window of its own, in the shell's colors through the olShell GTK theme (see [GTK](#gtk)). Scrolling over the volume widget adjusts the volume.

The btop window is as translucent as the widgets (the **Widget opacity** setting, read each time a window opens), so Hyprland blurs what's behind them if its blur is enabled. To make that possible the applications don't paint a background of their own (btop's `theme_background` is turned off in the copy of its config) and the terminal window's opacity is set to the widget opacity, overriding your terminal's own setting (only alacritty is handled, as for the colors).

## gdu

Clicking the disk widget (or `quickshell -p . ipc call gdu toggle`) opens [gdu](https://github.com/dundee/gdu), an interactive disk usage analyzer, on the disk mounted on `/`, and clicking again (or the same call) closes it. It shows which folders take the room, largest first: **Enter** goes into a folder, **←** back out, **d** deletes the selected item (with confirmation), **?** lists the other keys. (btop can't be used for this: it draws the disks inside its memory box, and nothing hides the memory part.) The window works like the others: [services/TuiWindow.qml](services/TuiWindow.qml) opens it floating and centered (60% × 70% of the monitor by default) with its own window class (`quickshell-gdu`), as translucent as the widgets.

gdu is started with `--no-cross`, so it stays on the filesystem of `/` (other disks and mounts such as `/boot/efi` aren't counted, as the widget doesn't count them; note that on btrfs, subvolumes such as `/home` count as other filesystems, so remove `--no-cross` in [scripts/tui-launch.py](scripts/tui-launch.py) there). It reads its styles from a file the launcher writes, `$XDG_RUNTIME_DIR/quickshell-gdu/gdu.yaml`, with the shell's colors for the header, footer, selected row and directories; that replaces gdu's default `~/.gdu.yaml` for this window only, so a configuration of yours is not used here (and never modified). The terminal and size are in [config/Apps.qml](config/Apps.qml) (`gduTerminal`, `gduWidth`, `gduHeight`).

## Launcher

The apps icon in the middle of the bar, or `quickshell -p . ipc call launcher toggle` (bind it to a key), opens a search box over the installed applications (their `.desktop` entries). Type to filter: matches names first (exact, prefix, word prefix, anywhere), then generic name, keywords, category and description, and finally letters in order (`ffx` finds Firefox). **↑/↓**, **Tab / Shift+Tab**, **Ctrl+N / Ctrl+P** (or **Ctrl+J / Ctrl+K**) and **Page Up / Down** move the selection, **Enter** launches it, **Escape** or a click outside closes. Hovering moves the selection too and a click launches; resting the pointer on an entry for half a second shows a tooltip with the real process name (e.g. "Fichiers" → `nautilus`), its full command and its desktop-entry id. With an empty search the list is alphabetical.


## Keyboard shortcuts

`quickshell -p . ipc call shortcuts toggle` (bind it to a key) opens a panel centered on the screen listing the shortcuts of the Hyprland config that use the **Super** key, keyboard and mouse (media keys, Print Screen and other keys without Super are left out), grouped (applications, shell, windows, workspaces) and described in the shell's language: "Go to workspace 1", "Open the launcher" for a shell IPC call, "Open zen-browser" with its full command under it. Type to filter (keys, description or command); **↑/↓** and **Page Up / Down** scroll, **Escape** or a click outside closes. A bind's own `description` option, if it has one, is shown instead.

A Lua config binds each shortcut to a Lua function, so Hyprland itself (`hyprctl binds`) only knows its keys: [scripts/list-shortcuts.py](scripts/list-shortcuts.py) reads what they do from the config's `hl.bind(...)` calls instead, each time the panel opens, following its `require(...)`s and resolving its string variables (`terminal`, `mainMod`...). Binds it can't read (built in a loop, say) are counted against Hyprland's own list of Super binds, and the panel says how many are missing.
## Themes

The theme panel (palette icon in the bar, or the IPC call below) lists **Automatique** followed by ten fixed themes: Catppuccin Mocha, Dracula, Nord, Gruvbox Dark, Tokyo Night, Solarized Dark, One Dark, Rosé Pine, Everforest Dark and Kanagawa. The **Automatique** button in the top-right corner jumps to its card and applies it. Left/Right browse; **Enter** or a click applies; **Escape** or a click outside closes. The choice is saved in `config/ThemeState.json` (git-ignored) and restored on startup.

- **Automatique** uses the palette matugen generates from the current wallpaper (below).
- A fixed theme ignores the wallpaper: changing the wallpaper still runs matugen, but the shell keeps the theme's colors until you switch back to Automatique.

To add or edit a theme, change the list in [config/ThemePresets.qml](config/ThemePresets.qml); each theme defines the same five colors as [matugen/quickshell-theme.json.template](matugen/quickshell-theme.json.template).

## Theming with matugen (Automatique)

Colors come from `config/GeneratedColors.json`, which matugen writes from the current wallpaper. The file is git-ignored; until it exists, the defaults in [config/GeneratedColors.qml](config/GeneratedColors.qml) are used.

[matugen/quickshell.toml](matugen/quickshell.toml) is a dedicated matugen config holding this shell's templates (its palette, and the colors of Hyprland, [Zen](#zen-browser), [alacritty](#alacritty) and starship), so applying a wallpaper or a theme doesn't also re-theme every app in your global `~/.config/matugen/config.toml`. [services/Matugen.qml](services/Matugen.qml) runs it:

- applying a wallpaper regenerates everything from it when **Automatique** is selected; a fixed theme ignores the wallpaper, which is only remembered;
- selecting a theme regenerates everything: from the wallpaper for **Automatique**, or from the theme's accent color for a fixed one.

A fixed theme has no image, only five colors, so matugen builds a full palette around its accent: the apps get colors in the theme's family, not its exact palette (Dracula's purple accent gives a purple-tinted dark background, not Dracula's own `#282a36`). The shell itself always uses a fixed theme's exact colors. Every run also rewrites `config/GeneratedColors.json`, which **Automatique** reads: while a fixed theme is selected it holds that theme's palette, so the "Automatique" card of the theme panel previews those colors, not the wallpaper's, and selecting **Automatique** regenerates it from the wallpaper (the shell shows the previous palette until matugen has finished, about a second). The last wallpaper is remembered in `config/ThemeState.json` for that; until a wallpaper has been applied once, that state is empty and selecting **Automatique** regenerates nothing.

The config is used straight from the checkout, with template paths relative to the file, so nothing has to be copied into `~/.config/matugen` and the checkout can live anywhere. Don't also declare these templates in your global `config.toml`, or a plain `matugen image …` would write them a second time.

## Zen browser

[matugen/quickshell.toml](matugen/quickshell.toml) also has a template, [matugen/zen-theme.css.template](matugen/zen-theme.css.template), which colors [Zen browser](https://zen-browser.app)'s interface — tabs, sidebar, URL bar, panels and the window background — with the theme the shell is using, so the browser follows the wallpaper and theme changes along with the bar. Remove the `[templates.zen]` block from `quickshell.toml` if you don't use Zen.

It writes `userChrome.css` into the Zen profile, which is the one place in that file that has to be edited for your machine: `output_path` points at the profile marked `Default=1` in `~/.config/zen/profiles.ini`. Firefox ignores `userChrome.css` unless one pref is on, so the profile also needs a `user.js` containing:

```js
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
```

Zen reads `userChrome.css` once, at startup: applying a wallpaper or a theme re-writes the file, but the browser only picks up the new colors the next time it starts (quit it completely first: launching it again while it runs only opens a window in the old process).

The template sets Zen's accent color (`--zen-primary-color`, which every other `--zen-colors-*` value is mixed from) and the surfaces Zen hardcodes rather than deriving from it, all in `!important` because Zen writes some of them as inline styles. It replaces the workspace background chosen in Zen's settings. Web pages aren't touched — this colors the browser, not what it displays.

## Alacritty

[matugen/quickshell.toml](matugen/quickshell.toml) also has a template for alacritty, [matugen/alacritty-theme.toml.template](matugen/alacritty-theme.toml.template), which writes the terminal colors (foreground, background, cursor, selection and the 16 ANSI colors) to `~/.config/alacritty/theme.toml`. Import that file from your `alacritty.toml`:

```toml
[general]
import = ["~/.config/alacritty/theme.toml"]
```

Alacritty reloads imported files while it runs, so open terminals recolor as soon as the wallpaper or theme changes, with no restart (unlike [Zen](#zen-browser)). Remove the `[templates.alacritty]` block from `quickshell.toml` if you don't use alacritty. The same goes for the `[templates.hyprland]` (writes `~/.config/hypr/colors.lua`) and `[templates.starship]` (writes `~/.config/starship/starship.toml`, **replacing** that file: keep your prompt's layout in the template) blocks. The btop and gdu windows the shell opens set their own colors from the shell's theme and don't use this file.

## GTK

[matugen/gtk-theme.css.template](matugen/gtk-theme.css.template) only defines the GTK named colors (window, view, header bar, sidebar, card, dialog and popover backgrounds, accent, ...) from the shell's palette; GTK builds the widgets from them. [matugen/quickshell.toml](matugen/quickshell.toml) writes it for each kind of GTK app:

- **libadwaita apps** (Nautilus and most GNOME apps) read it as `~/.config/gtk-4.0/gtk.css` (`[templates.gtk4]`), whatever GTK theme is set. They pick up new colors as they start.
- **GTK3 apps and plain GTK4 ones** (Blueman, nm-applet, pavucontrol, HandBrake...) get it through the **olShell** GTK theme, which matugen writes to `~/.local/share/themes/olShell/`: [adw-gtk3](https://github.com/lassekongo83/adw-gtk3)-dark (built on those names) followed by these colors, for GTK3 (`gtk-3.0/`) and GTK4 (`gtk-4.0/`), from [gtk3-theme-index.css.template](matugen/gtk3-theme-index.css.template) and [gtk4-theme-index.css.template](matugen/gtk4-theme-index.css.template). Running apps never re-read a `gtk.css`, but they do reload their theme as its name changes, so a hook switches the name away and straight back after each run: open windows recolor at once.

To set it up:

- Install adw-gtk3 (`adw-gtk-theme` on Arch), run a theme or wallpaper change once so matugen writes the olShell theme, then select it: `gsettings set org.gnome.desktop.interface gtk-theme olShell`, and `gtk-theme-name=olShell` in `~/.config/gtk-3.0/settings.ini`. Restart already running GTK apps once.
- Don't keep a `~/.config/gtk-3.0/gtk.css`: an app reads it as it starts, above the theme, so it would pin that moment's colors.
- `~/.config/gtk-4.0/gtk.css` and `gtk-dark.css` must not be symlinks to a GTK theme (as `nwg-look`'s "export GTK4 symlinks" option or a theme installer leaves them): matugen would write through the link into the theme's own file, fail if it isn't yours, and stop the whole run there. Remove the links (and turn that option off); libadwaita prefers `gtk-dark.css` in dark mode, so a leftover one also hides the generated colors.
- Set the `org.gnome.desktop.interface color-scheme` to `prefer-dark` so the apps use the dark variant the palette is generated for (`gsettings set org.gnome.desktop.interface color-scheme prefer-dark`).
- Remove the `gtk*` blocks from `quickshell.toml` if you don't want GTK apps themed.

## Clock popup

Clicking the clock opens a popup (a click on the clock again, or anywhere outside the popup, closes it) with a tab bar: **Agenda** (the default tab: a month calendar, weeks starting on Monday with ISO week numbers; the arrows browse months, "Aujourd'hui" jumps back, today is highlighted; no events yet) and **Performances** (see the next section). The popup is as wide as its tab bar needs (520 px at least) and as tall as the tab being shown. To add a feature, append an entry to `tabs` and a page to the `StackLayout` in [ClockPanel.qml](modules/Bar/Widgets/ClockPanel.qml).

## Performances

The **Performances** tab of the clock popup shows the machine's load at a glance, refreshed live:

- **Processeur** and **Mémoire**: a ring gauge with the current percentage (the CPU card adds frequency and core count, the memory card used / total), and a sparkline of the last samples.
- **Réseau**: instant download and upload speed with a sparkline of the last minute each. Only physical interfaces are counted (found through `/sys/class/net`), so a VPN or docker doesn't count the same traffic twice.
- **Stockage**: the main disk, the one mounted on `/`, with used / capacity and a usage bar. (`SystemStats.disks` lists every mounted disk, without pseudo file systems such as tmpfs and with a device mounted several times, e.g. btrfs subvolumes, listed once; the tab filters it to `/`.) Gauges and bars turn to `Theme.warningColor` above 90%.

The right part of the bar also has a disk widget (`DiskUsage`, after the RAM widget) showing how full the main disk, the one mounted on `/`, is, in percent (in the warning color above 90%); hovering it shows the used space over the capacity (e.g. "825.8 GiB used / 915.3 GiB"). It reads the same figures as the storage card above (`SystemStats.rootDisk`, refreshed every 20 s), and clicking it opens [gdu](#gdu) on that disk. It also has an instant download / upload speed widget (`NetworkSpeed`, between the disk and volume widgets), fed by the same network figures, refreshed every second. Its numbers have fixed widths so the bar does not shift as they change.

The figures come from [services/SystemStats.qml](services/SystemStats.qml), which the CPU and RAM widgets share, so they're polled once however many monitors there are: CPU every 2 s, memory every 3 s, network every second, disks every 20 s.

## Wallpapers

The picker lists images from `~/.config/wallpapers/bing/saved/`, plus `~/.config/wallpapers/bing/pod.jpg` (the Bing picture of the day) as the first entry. Both locations, and the config directory root (`$XDG_CONFIG_HOME`), are set in [config/Paths.qml](config/Paths.qml).

Left/Right browse without changing anything; **Enter**, clicking a picture, "Image du jour" or "Aléatoire" (top right, next to it: a random wallpaper other than the one in use) applies it (awww sets it, matugen regenerates the palette). **Escape** or a click outside closes the panel.

Applying goes through [scripts/apply-wallpaper.py](scripts/apply-wallpaper.py), which runs `awww img`. awww draws nothing unless its daemon (`awww-daemon`) is running, so the script starts it, detached from the shell, when it isn't, which means nothing has to start it at login: the shell applies the last wallpaper (the one remembered in `config/ThemeState.json`) as soon as it starts, and again 5 seconds later if it is the picture of the day (in case a new one was downloaded meanwhile), so the wallpaper is back at login (the `applyLast` IPC call does the same on demand, see [IPC](#ipc)); the shell no longer uses waypaper, so waypaper's own config is not updated and `waypaper --restore` would restore an older image. The transition's type and duration (a 2 s fade by default) are [settings](#settings); the image fill and the transition's smoothness are the `wallpaperOptions` of [config/Apps.qml](config/Apps.qml), any `awww img` options.

## IPC

Bind these to keys, e.g. from Hyprland:

```sh
quickshell -p . ipc call wallpapers wallpapersToggle   # open/close the wallpaper panel
quickshell -p . ipc call wallpapers applyPod           # apply the Bing picture of the day
quickshell -p . ipc call wallpapers applyRandom        # apply a random wallpaper other than the current one
quickshell -p . ipc call wallpapers applyLast          # apply the last applied wallpaper again (e.g. after a new picture of the day was downloaded)
quickshell -p . ipc call btop toggle                   # open/close the full btop window
quickshell -p . ipc call btop cpu                      # ... showing only the CPU box (also: memory, network)
quickshell -p . ipc call gdu toggle                    # open/close the gdu window
quickshell -p . ipc call launcher toggle               # open/close the application launcher
quickshell -p . ipc call shortcuts toggle              # open/close the keyboard shortcuts panel
quickshell -p . ipc call settings toggle               # open/close the settings panel
quickshell -p . ipc call notifications toggle          # open/close the notification center
quickshell -p . ipc call notifications dnd 1           # do not disturb on (0: off); also toggleDnd, clear, count
quickshell -p . ipc call themes themesToggle       # open/close the theme panel
quickshell -p . ipc call lock lock                # lock the screen (`lock status` prints 1 while locked)
quickshell -p . ipc call power toggle              # open/close the power panel
quickshell -p . ipc call power logout              # ask to confirm logging out (also: restart, shutdown)
quickshell -p . ipc call volume increase 0.05
quickshell -p . ipc call volume decrease 0.05
quickshell -p . ipc call volume mute
```

Volume changes from any source (these calls, media keys, pavucontrol...) also show the OSD.

## Screenshots

The camera button in the middle of the top bar takes a screenshot: a **left click** captures in the mode chosen last, a **right click** opens a menu to choose a mode (the current one is in the accent color), and choosing one remembers it and takes the screenshot at once (after a quarter of a second, so the menu is gone from the picture). The modes:

- **Screen**: the focused monitor.
- **Rectangle**: draw the area with the mouse ([slurp](https://github.com/emersion/slurp)).
- **Window**: click one of the windows on show on any monitor's workspace.

The last row of the right-click menu, **Annotate with Satty**, switches an annotation step on or off (remembered; ticked and in the accent color when on). With it on, each screenshot is also opened in [Satty](https://github.com/gabm/satty) once taken, to draw arrows, boxes, text, blur and so on: **Enter** there copies the annotated picture to the clipboard and saves it next to the original as `screenshot-<date>_<time>-edited.png`, then closes Satty (its toolbar has more save options). The original is kept and copied first, so closing Satty without doing anything leaves you the plain picture; no notification is shown in that case, since Satty announces its own. It needs `satty`; without it the switch does nothing.

The picture is saved as `~/Pictures/Screenshots/screenshot-<date>_<time>.png` (the folder is created; the settings panel's General category has a **Screenshot folder** field to change it: click it or press **Enter**, type, **Enter** again to save, **Escape** to cancel; `~` is your home folder, and anything that isn't an absolute path is refused and puts back the default), copied to the clipboard, and announced with a notification showing it. Escape while choosing an area cancels. [scripts/screenshot.py](scripts/screenshot.py) does the work with `grim`, and [services/Screenshot.qml](services/Screenshot.qml) keeps the mode (`screenshotMode` and `screenshotEdit` in `config/Settings.json`, not in the settings panel; the folder, `screenshotDir`, is) and answers the IPC calls:

```sh
quickshell -p . ipc call screenshot capture         # in the remembered mode (bind this to a key, e.g. Print)
quickshell -p . ipc call screenshot take window     # in another mode, without remembering it (screen, region or window; the argument is required)
quickshell -p . ipc call screenshot mode region     # remember a mode
quickshell -p . ipc call screenshot edit 1          # annotate with Satty afterwards (0: don't)
quickshell -p . ipc call screenshot dir ~/Shots     # where pictures go (no argument: print it)
```

The button is a bar widget like the others: it can be moved, turned off or given a divider from the settings panel's Widgets category. It is in the middle of the bar by default; a layout saved before it existed doesn't have it until you put it in a pill there (or `settings place screenshot center -1`). The clipboard copy and the notification are skipped if `wl-copy` or `notify-send` isn't installed.

## Notifications

olShell is a desktop notification server (the `org.freedesktop.Notifications` D-Bus service that `notify-send` and applications talk to), so it takes the place of mako, dunst or swaync: **only one of them can run**. Stop the other one and keep it from starting again (for swaync: `systemctl --user mask swaync`, since it is started by D-Bus on the first notification, and remove any autostart line for it), otherwise whichever starts first keeps the name and olShell logs "Could not register notification server".

- **Pop-ups** appear on the focused screen, at the top right by default (the *Notification position* setting puts them in another corner, at the middle of the top or bottom edge or halfway down the left or right one; at the top they are under the bar, and the newest is always the one nearest the edge):  the icon (the notification's image, else its application icon), summary, body (basic markup and links work) and one button per action. They stay for the *Pop-up duration* setting, or the time the sender asked for; urgent ones stay until closed; a line along the bottom shows the time left, and the timer stops while the pointer is over the pop-up. At most *Pop-ups at once* are shown, the others wait their turn. **Click** a pop-up to run its default action (if it has one) and put it away into the center; the cross closes it for good.
- **The center** is opened by the bell in the bar (or `ipc call notifications toggle`): every notification received, by application (newest first), in a panel put where the pop-ups appear (the same *Notification position* setting), with the time, a cross per notification and per application, and **clear all**. Clicking a notification with a default action runs it and closes it. **Escape** or a click outside closes it; opening it puts any pop-ups away, since it shows them.
- **The bell** is a bar widget like the others, just before the power button by default (a layout saved before it existed doesn't have it until you put it in a pill in the settings' Widgets category, or `settings place notifications right`). The bell is accent-colored while the center has notifications, and red while one of them is urgent. Their number is written to the right of the bell: it goes down only when one is dismissed, not when its pop-up goes away. A **right click** switches *do not disturb* on or off (also in the center's header and the settings' Notifications category): the bell is crossed out and no pop-up shows, except for urgent notifications; everything still goes to the center.
- The history is kept in memory: it is lost when the shell restarts. A notification an application replaces (`notify-send -r`) or closes is updated or removed here too.

[services/Notifications.qml](services/Notifications.qml) is the server and answers the IPC calls; [modules/Notifications/](modules/Notifications) has the pop-ups, the center and the notification card.

## Power

The power icon at the end of the bar (or `quickshell -p . ipc call power toggle`, to bind to a key) opens a panel with three actions side by side: **Log out**, **Restart** and **Shut down**. **←/→** (or **Tab**) move between them, **Enter** or a click picks one, **Escape** or a click outside closes. Picking one closes the panel and asks for confirmation (Enter or **Confirm** runs it, Escape or **Cancel** drops it). `ipc call power logout`, `restart` and `shutdown` skip the panel and go straight to that confirmation, so a script never powers the machine off unasked. Logging out is Hyprland's exit; the others are `systemctl reboot` and `systemctl poweroff`. The panel is [modules/Power/PowerPanel.qml](modules/Power/PowerPanel.qml), the confirmation [components/PowerConfirmDialog.qml](components/PowerConfirmDialog.qml) and the commands are in [config/PowerMenuState.qml](config/PowerMenuState.qml).

## Lock screen

The padlock icon just before the power icon (or `quickshell -p . ipc call lock lock`, to bind to a key) locks the screen. It is a Wayland session lock ([modules/Lock/LockScreen.qml](modules/Lock/LockScreen.qml)): the compositor shows only the lock surfaces, one per monitor, with the time, the date and a password field over the current wallpaper, blurred and slightly darkened (the theme background when there is none), until the password is right. Type it and press **Enter**; it is checked by PAM against your own login (the `login` stack, [services/Lock.qml](services/Lock.qml)), so it is the password you log in with. A wrong one says so and empties the field. The **Lock screen** category of the settings has **Lock after**: the minutes without keyboard or mouse input before the screen locks by itself, from 1 to 60, or **never** (0); the default is 10 (`lockTimeout` in `config/Settings.json`; `settings set lockTimeout 5`). Anything that inhibits idling (a video playing, for one) holds the timer off. `ipc call lock status` prints 1 while the screen is locked, else 0. There is no unlock call, on purpose.

Reloading the shell (saving a file while developing it) while the screen is locked breaks the lock, and Hyprland then shows a lock-crashed message. To get out, switch to a text console (Ctrl+Alt+F3), log in, and run `hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'` then `hyprctl --instance 0 dispatch exec hyprlock` (Hyprland's hyprlock takes the lock over and unlocks with your password); or set `misc:allow_session_lock_restore = true` in your Hyprland config beforehand, so that starting the shell again is enough.

## Lock keys OSD

Switching Caps Lock or Num Lock on or off briefly shows a popup at the bottom of the screen, next to where the volume OSD appears, with the key's icon and its new state (accent-colored when on). The state isn't announced at startup, only on changes.

[services/LockKeys.qml](services/LockKeys.qml) runs [scripts/lock-keys-watch.py](scripts/lock-keys-watch.py), which polls the lock LEDs the kernel exposes in `/sys/class/leds/*::capslock` and `*::numlock` (ten times a second, from one process) and reports each change. A lock counts as on when any keyboard's LED is on, and keyboards plugged in later are picked up. This works on any compositor but needs those LEDs to exist, which is the case for ordinary keyboards.
