# olShell

olShell is a [Quickshell](https://quickshell.org) shell for Hyprland: a top bar replicated on every monitor, a btop window (click the CPU, RAM or network-speed widget to see just that part), pavucontrol for the audio mixer (click the volume widget), a gdu disk usage window (click the disk widget), an application launcher, a wallpaper picker and a theme picker (automatic from the wallpaper, one of 10 fixed themes with their light versions, or your own colors), a clock popup with an agenda and performance figures, live CPU / RAM / network-speed widgets, a volume OSD, a screenshot button, a notification center with pop-ups, a Caps Lock / Num Lock OSD and a lock screen (by idle timer or a button), a power panel with confirmation, all in English, French or Spanish.

## Requirements

The versions it runs on are Quickshell 0.3, Hyprland 0.56 and matugen 4.2; older ones may lack what it uses (noted below). Package names are Arch's where they differ.

Needed:

- [Quickshell](https://quickshell.org), with its Hyprland, Wayland, PipeWire, notifications, PAM, polkit, system tray, Bluetooth and networking modules (all in the standard build)
- Hyprland with its Lua config: the shell sets things at run time with `hyprctl eval` (zoom, blur, the synced window look, `QS_CONFIG_PATH`), and the shortcuts panel reads the config's `hl.bind(...)` calls
- Python 3, standard library only, for the helpers in `scripts/`
- the Adwaita icon theme (`adwaita-icon-theme`), where the shell looks up the apps' icons (an app whose icon isn't found gets a generic glyph in the launcher)
- a Nerd Font, used for text and icons: "0xProto Nerd Font" by default, changeable in the settings (see [Settings](#settings))
- PipeWire (volume), PAM (lock screen), systemd (`systemctl` for restart, shut down, suspend and UEFI setup) and the usual command-line tools (`sh`, `find`, `awk`, `xargs`, `stat`, `df`, `grep`)

For the features that use them:

- [matugen](https://github.com/InioX/matugen) 4 or later (its templates use `<* if *>` conditions and data passed with `--import-json-string`) and [awww](https://codeberg.org/LGFae/awww) for the wallpaper picker and the themes (awww is the wallpaper daemon; the shell starts it when it isn't running)
- [`pavucontrol`](https://freedesktop.org/software/pulseaudio/pavucontrol/) for the audio mixer (volume click)
- `btop` and [`gdu`](https://github.com/dundee/gdu) for the btop and disk usage windows, and a terminal for them and for the terminal applications started from the launcher (`alacritty` by default, configurable in [config/Apps.qml](config/Apps.qml))
- `grim` and `slurp` for the screenshot button, and optionally `wl-clipboard` (`wl-copy`, to copy the picture), `libnotify` (`notify-send`, to announce it) and [`satty`](https://github.com/gabm/satty) (to annotate it)
- [`fd`](https://github.com/sharkdp/fd) for the launcher's files (and the chat AI's file searches, with [`ripgrep`](https://github.com/BurntSushi/ripgrep) for its text searches; both fall back to plain Python without them), `xdg-utils` (`xdg-open` to open a file or an address, `xdg-settings` to find the default browser's search engine) and `nautilus` (to show a file in its folder)
- NetworkManager (`nmcli`) and `nm-connection-editor` for the network connection widget, and BlueZ with [blueman](https://github.com/blueman-project/blueman) for the Bluetooth widget's windows (blueman's own tray icon, whose applet starts along with those windows, is left out of the tray: `hiddenTrayItems` in [config/Apps.qml](config/Apps.qml))
- [hyprpicker](https://github.com/hyprwm/hyprpicker) for the color picker's **From the screen** (custom theme)
- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) (`adw-gtk-theme`) and `gsettings` (`glib2`) for GTK apps in the shell's colors (see [GTK](#gtk))
- optionally [qt6ct](https://github.com/trialuser02/qt6ct) and [qt5ct](https://sourceforge.net/projects/qt5ct/) for Qt apps in the shell's colors (see [Qt](#qt))
- `secret-tool` (`libsecret`) and a Secret Service keyring (GNOME Keyring, KWallet...) for the chat AI panel's API keys, and an account with an AI provider or a local server (see [Chat AI](#chat-ai))
- optionally [Zen browser](https://zen-browser.app) and [starship](https://starship.rs), which matugen can color with the shell's palette (see [Zen browser](#zen-browser))

## Structure

```
.
├── shell.qml                 # Shell root — wires modules together
├── config/
│   ├── Theme.qml             # Sizes, font, corner radius, border width and colors shared by every widget
│   ├── GeneratedColors.qml   # Active palette: selected theme, or matugen's GeneratedColors.json
│   ├── ThemePresets.qml      # The selectable themes ("auto", 10 fixed ones with their dark and light versions and accents, "custom"), and the active one as used
│   ├── ThemeState.qml        # Selected theme and last wallpaper, saved in ThemeState.json
│   ├── Settings.qml          # Adjustable values (look-and-feel, wallpaper transition), saved in Settings.json (Theme reads them), and the user's own defaults in UserDefaults.json
│   ├── Defaults.qml          # The built-in default of every setting (read-only: nothing writes to it)
│   ├── SettingsPanelState.qml   # Shared visibility of the settings panel
│   ├── I18n.qml, Translations.qml   # Localization: language choice + lookup, and the English / French / Spanish texts
│   ├── ThemePanelState.qml   # Shared visibility of the theme panel
│   ├── LauncherState.qml     # Shared visibility of the launcher, and the apps last opened from it, saved in LauncherState.json
│   ├── ShortcutsPanelState.qml # Shared visibility of the keyboard shortcuts panel
│   ├── ChatAiState.qml       # Shared visibility of the chat AI panel, and the provider picked in it
│   ├── AppSwitcherState.qml  # Shared visibility and selection of the app switcher
│   ├── NotificationCenterState.qml   # Shared visibility of the notification center
│   ├── Paths.qml             # Wallpaper, matugen and palette locations
│   ├── Apps.qml              # Commands launched by clicking widgets
│   ├── BarSlots.qml          # Each screen's bar slot that an attached panel moves its frame into
│   ├── ClockPanelState.qml   # Shared visibility of the clock panel
│   ├── NotificationActions.qml, NotificationActionsState.qml   # Commands run when a notification arrives (saved in NotificationActions.json), and their panel's state
│   ├── PowerMenuState.qml    # Pending power action + the commands that run it
│   ├── PowerPanelState.qml   # Shared visibility of the power panel
│   ├── WallpaperPanelState.qml   # Shared visibility of the wallpaper panel
│   └── *.json                # Runtime state, git-ignored: Settings, UserDefaults, ThemeState, LocaleState, LauncherState, GeneratedColors, NotificationActions
├── services/
│   ├── Audio.qml             # Default output volume/mute + `volume` IPC target
│   ├── Screenshot.qml        # Takes screenshots (mode remembered) + `screenshot` IPC target
│   ├── Lock.qml              # Lock state, password check (PAM) + `lock` IPC target
│   ├── Notifications.qml     # The notification server (history, do not disturb) + `notifications` IPC target
│   ├── LockKeys.qml          # Caps Lock / Num Lock state, from scripts/lock-keys-watch.py
│   ├── DesktopLocale.qml     # Application names/descriptions in the shell's language, read from the .desktop files
│   ├── WebSearch.qml         # The launcher's web search engines, with the default browser's own (from scripts/default-search-engine.py)
│   ├── TuiWindow.qml         # A TUI app in a floating, themed terminal window that opens/closes like a panel
│   ├── Btop.qml              # The btop window (toggle + `btop` IPC target)
│   ├── Gdu.qml               # The gdu window (toggle + `gdu` IPC target)
│   ├── Matugen.qml           # Runs matugen when a wallpaper is applied or a theme is selected
│   ├── ConfigPath.qml        # Points Hyprland's QS_CONFIG_PATH at the folder the running shell comes from
│   ├── Polkit.qml            # The polkit authentication agent (the requests PolkitDialog answers)
│   ├── NetworkManager.qml    # What the connection widget reads and does through nmcli (networking on/off, VPNs, connection details)
│   ├── Zoom.qml              # Screen zoom through Hyprland's cursor:zoom_factor + `zoom` IPC target
│   ├── Blur.qml              # Keeps Hyprland's blur of the shell's surfaces, and its blur options, in sync with the settings
│   ├── HyprlandWindows.qml   # Sets Hyprland's window border, radius, gaps and opacity (per app too) from the settings
│   ├── HyprlandAnimations.qml   # Sets Hyprland's animations (on/off, duration, window and workspace styles) on top of its config's
│   ├── WorkspaceRules.qml    # The workspaces the Hyprland config has a rule for
│   ├── SystemStats.qml       # CPU, RAM, network speed and disks, with short histories (polled once, not per monitor)
│   ├── ChatAi.qml            # The chat AI panel's question and answer (asked through scripts/ai-ask.py, the last one saved in ChatAiState.json), its providers, their keys and models
│   ├── KeyringPrompt.qml     # Puts the open panel aside while GNOME Keyring's password prompt is open, so it can be seen and typed in
│   ├── WorldClock.qml        # The clocks tab's places and their time now (offsets from scripts/timezones.py), and adding one by name
│   └── Weather.qml           # The weather tab's forecast, from Open-Meteo, for the place set or found from the internet address + `weather` IPC target
├── components/               # Generic building blocks shared by the widgets (import qs.components)
│   ├── ThemedText.qml        # Text in the shell's font and color
│   ├── Pill.qml, BarStack.qml, BarText.qml, BarGauge.qml, Linger.qml, Separator.qml, IconButton.qml, TabBar.qml, PowerMenuOption.qml, PopupTitle.qml   # Bar pill, row-or-column layout, text, side-bar ring gauge, divider, buttons, popup title, keep-alive for closing panels
│   ├── PopupMenu.qml, HoverPopup.qml   # Popup windows: a menu, and one opened by hovering
│   ├── ModalPanel.qml        # Base of the full-screen panels: backdrop, frame, keyboard focus
│   ├── CarouselPanel.qml, CarouselCard.qml   # Base of the two pickers (wallpapers, themes)
│   ├── RingGauge.qml, Sparkline.qml   # Gauge and area chart
│   ├── PowerConfirmDialog.qml   # Confirmation shown after picking a power action
│   ├── Fillet.qml, BarFillets.qml   # Concave corners where a surface meets the bar
│   ├── CheckBox.qml          # A check box (drawing only)
│   └── SettingSlider.qml, ChoiceRow.qml, DropdownRow.qml, ToggleRow.qml, PathRow.qml, SearchEngineRow.qml, DefaultsRow.qml, PositionIcon.qml, DisabledTooltip.qml, ColorPicker.qml, ThemeAppRow.qml, ChatAiProviderRow.qml   # Rows of the settings panel
├── modules/                  # One directory per feature (import qs.modules.<Name>)
│   ├── Bar/                  # The top bar
│   │   ├── Bar.qml           # Top bar, one per screen: three WidgetZones
│   │   ├── WidgetZone.qml, WidgetSlot.qml   # A pill filled from Settings.layout, and one widget in it with its divider
│   │   ├── BarWidgets.qml    # The widgets by id (a singleton)
│   │   └── Widgets/          # What sits in the bar (import qs.modules.Bar.Widgets)
│   │       ├── Workspaces, ActiveWindow, Clock, WallpaperTrigger, ThemeTrigger, LauncherTrigger, LanguageTrigger, SettingsTrigger, ShortcutsTrigger
│   │       ├── ScreenshotButton, ZoomButton
│   │       ├── Tray, TrayItem, TrayMenuItem, TraySubmenu
│   │       ├── CpuUsage, RamUsage, DiskUsage, NetworkSpeed, ConnectionButton, BluetoothButton, Volume, NotificationBell, LockButton
│   │       ├── PowerTrigger
│   │       └── ChatAiTrigger
│   ├── Clock/ClockPanel.qml, AgendaTab.qml, PerformanceTab.qml, MediaTab.qml, WeatherTab.qml, WorldClockTab.qml   # Clock popup: tab bar + pages (agenda, performance, media player, weather, clocks)
│   ├── Launcher/LauncherModule.qml    # Builds the launcher only while it is open, and holds its IPC target
│   ├── Launcher/LauncherPanel.qml     # Application launcher (ModalPanel + desktop entries)
│   ├── AppSwitcher/AppSwitcherModule.qml   # Builds the app switcher only while it is open, and holds its `switcher` IPC target
│   ├── AppSwitcher/AppSwitcherPanel.qml    # Hyprland's windows, the most recently focused first, to switch to
│   ├── Shortcuts/ShortcutsModule.qml  # Builds the shortcuts panel only while it is open, and holds its IPC target
│   ├── Shortcuts/ShortcutsPanel.qml   # The Hyprland config's shortcuts, grouped and searchable
│   ├── ChatAi/ChatAiModule.qml        # Builds the chat AI panel only while it is open, and holds its `chatai` IPC target
│   ├── ChatAi/ChatAiPanel.qml         # One question to an AI provider, one answer (ModalPanel)
│   ├── Notifications/        # NotificationPopups (the pop-ups), NotificationCenter (the history panel), NotificationCard, NotificationActionsPanel (commands run on a notification), NotificationActionsModule (builds it only while it is open, and holds its IPC target)
│   ├── Lock/LockScreen.qml   # The lock screen (session lock) + the idle timer
│   ├── Polkit/PolkitDialog.qml    # The password dialog of the polkit agent (ModalPanel)
│   ├── Power/PowerModule.qml # Builds the power panel only while it is open, and holds its IPC target
│   ├── Power/PowerPanel.qml  # The power panel: log out, restart, shut down (ModalPanel)
│   ├── Osd/                  # Popups shown for a moment, each where its position setting puts it
│   │   ├── VolumeOsd.qml, VolumePill.qml   # Volume (the pill is also on the lock screen)
│   │   ├── LockKeysOsd.qml   # Caps Lock / Num Lock
│   │   ├── ZoomOsd.qml       # Zoom factor
│   │   └── ZoomShield.qml    # Takes the input while zoomed with the look-only zoom setting
│   ├── Settings/SettingsModule.qml    # Builds the settings panel only while it is open (or picking a color), and holds the `settings` IPC target
│   ├── Settings/SettingsPages.qml     # The settings' categories, rows and defaults functions, used by the panel and the IPC calls
│   ├── Settings/SettingsPanel.qml     # Settings panel (built from SettingSlider, ChoiceRow, DropdownRow, ToggleRow and the other rows)
│   ├── Settings/BarLayoutEditor.qml   # The bar widgets' Layout tab: the bar's zones, groups and widgets, arranged by dragging
│   ├── Theme/ThemeModule.qml          # Builds the theme picker only while it is open, and holds its IPC target
│   ├── Theme/ThemePanel.qml           # Theme picker (CarouselPanel + ThemeState)
│   └── Wallpapers/WallpaperPanel.qml  # Wallpaper picker (CarouselPanel + awww/matugen)
├── .claude/                  # Claude Code skills (add-setting, add-panel, add-bar-widget, test-deploy) and their check scripts; not deployed (.gitattributes)
├── scripts/apply-wallpaper.py   # Shows an image as the wallpaper with awww, starting its daemon if needed (used by the wallpaper panel)
├── scripts/screenshot.py        # Takes a screenshot (screen, rectangle or window), saves and copies it (used by services/Screenshot.qml)
├── scripts/lock-keys-watch.py   # Prints the Caps/Num Lock state on every change (used by services/LockKeys.qml)
├── scripts/timezones.py     # Time zones' UTC offsets now, as JSON (for the clocks tab)
├── scripts/list-shortcuts.py # Reads the shortcuts from the Hyprland config, as JSON (for the shortcuts panel, and the app switcher's own shortcut)
├── scripts/tui-launch.py     # Themes and starts btop or gdu in a terminal (used by services/TuiWindow.qml)
├── scripts/default-search-engine.py # Reads the default browser's default search engine, as JSON (for the launcher's web search)
├── scripts/ai-ask.py         # Asks an AI provider one question, with read-only tools over the home folder, this README and the shell's settings, the shell's IPC calls and the web search of Anthropic and OpenAI (used by services/ChatAi.qml)
├── scripts/ai-key.py         # Keeps the AI providers' API keys in the secret keyring (used by services/ChatAi.qml)
├── scripts/matugen-run.py    # Runs matugen with only the templates of the apps turned on, plus the added apps' (used by services/Matugen.qml)
└── matugen/                  # Everything matugen: its config and every template it fills
    ├── quickshell.toml       # The config: the shell's palette and the other apps' colors (Hyprland, Zen, alacritty, GTK, Qt, starship)
    ├── active.toml           # The same with only the apps turned on, written before each run (git-ignored)
    ├── quickshell-theme.json.template   # Template of the shell's palette (written to config/GeneratedColors.json)
    ├── hyprland-theme.lua.template      # Template of Hyprland's colors (~/.config/hypr/colors.lua)
    ├── zen-theme.css.template           # Template coloring Zen browser
    ├── alacritty-theme.toml.template    # Template coloring alacritty
    ├── gtk-theme.css.template           # Template of the GTK named colors (libadwaita, and the olShell theme's)
    ├── gtk3-theme-index.css.template    # The olShell GTK theme's GTK3 part (adw-gtk3-dark, or adw-gtk3 in light, + the colors)
    ├── gtk4-theme-index.css.template    # The olShell GTK theme's GTK4 part, for plain GTK4 apps
    ├── qt-colors.conf.template          # The olShell qt5ct / qt6ct color scheme, for Qt apps
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
| Appearance | Curve radius (of the curved joins between the bar and what's attached to it, and between a submenu and its menu; only with curved joins on, no gap and no border) | 0 – 60 px | 5 |
| Appearance | Same as the widget radius (the curves follow the widget radius above, instead of their own) | check box | on |
| Animations (General tab) | Animate (the auto-hiding bar sliding in and out; the bar widgets' popups and menus, and the panels attached to the bar, slide out from under the bar, or from under their menu, and fade in; the other panels fade in while growing from slightly smaller; all go back the same way as they close; off, they snap) | check box | on |
| Animations (General tab) | Animation duration (only while animating) | 50 – 600 ms | 160 ms |
| Animations (Hyprland tab) | Animate windows and workspaces (Hyprland's own animations on or off) | check box | on |
| Animations (Hyprland tab) | Duration: a multiplier on the duration of every animation the Hyprland config sets (×2 makes them last twice as long, ×0.5 half as long; ×1 leaves the config's) | ×0.25 – ×4 | ×1 |
| Animations (Hyprland tab) | Same as the shell's animation duration (every Hyprland animation then takes the General tab's animation duration; the multiplier above has no effect) | check box | off |
| Animations (Hyprland tab) | Windows opening and closing, and Switching workspaces: the style of those animations, or the Hyprland config's | As in the Hyprland config / Pop in / Slide / Grow from a line, and As in the Hyprland config / Slide / Slide vertically / Fade / Slide and fade / Slide vertically and fade | As in the Hyprland config |
| Appearance (Blur tab) | Blur: radius, passes, vibrancy, contrast, brightness, noise, and x-ray (blur only the wallpaper, not the windows behind; for the shell's surfaces through its layer rule, since Hyprland's own option only reaches floating windows). Hyprland's own blur options (`decoration.blur`), set live while the blur is on (greyed out while it's off; turning the blur off disables Hyprland's blur for the windows too); they are global, so transparent windows get them too, and they replace the Hyprland config's values while the shell runs | 1 – 20 px / 1 – 8 / 0 – 100 % / 0 – 200 % / 0 – 200 % / 0 – 20 % / on or off | 3 px / 3 / 17 % / 89 % / 100 % / 1.2 % / off |
| Appearance (Hyprland tab) | Hyprland's window look, which the shell sets live, replacing the Hyprland config's values: synced with the shell, the window border width and corner radius (each its own, or with the link button after its name the same as the shell's border width and widget radius; the radius less the window border, since Hyprland draws the border outside the corner, so a window's outer edge matches a widget's) and the gap between windows (`gaps_in`, its own, or with that button the same as the shell's gap between elements); Hyprland only, the gap around the windows (`gaps_out`) and, on one Opacity line, the opacity of the focused window and of the others (which fades a whole window, text included, unlike the widget opacity), each its own, or with the link button after it the same as the shell's opacity; the corners are always circular (`rounding_power` 2), like the shell's | border 0 – 10 px; radius 0 – 30 px; gaps 0 – 40 px and 0 – 80 px; opacities 10 – 100 % | 2 px; 10 px; 3 px and 5 px; 100 % |
| Appearance (App opacity tab) | Opacity per application: an app picked among those with a window open gets its own opacity when focused and when not, replacing the Hyprland tab's window opacities (its Opacity line, laid out the same way) for its windows (a Hyprland window rule per app, set live, open windows included, and set again after every Hyprland config reload). Each app is one line, sorted by name: its icon and name, the two sliders, each with a link button making it follow the Hyprland tab's opacity instead, and a button putting it back on the general opacities; on the keyboard, ← → move the slider the keys are on (on a button, go to the thing before or after it), Space or Enter goes from a slider to its link button and switches the link (on the last button, removes the app), Delete removes the selected app | 10 – 100 % each | none |
| Text | Font size | 10 – 32 px | 18 |
| Text | Font weight | Thin / Extra light / Light / Normal / Medium / Semi bold / Bold / Extra bold / Black (100 – 900) | Normal |
| Text | Letter spacing | -2 – 6 px | 0 |
| Text | Capitalization | As typed / UPPERCASE / lowercase / Small caps | As typed |
| Text | Font style | Italic, underline, outline (each on / off) | all off |
| Text | Font | the installed Nerd Font families | 0xProto Nerd Font |
| Top bar | Auto-hide the bar | on / off (check box); tucks the bar away until the pointer reaches the edge of the screen it's anchored to | off |
| Top bar | Hide delay | 0 – 3000 ms; how long the pointer has to be away before it tucks away again | 500 ms |
| Top bar | Bar position (on the left or right edge the widgets stack in a column: the left zone at the top, the right one at the bottom; CPU, RAM, disk, volume and network speed show as rings around their icon filled to their value (the figures in their popup), the other widgets their figure under their icon, the clock its hours over its minutes, the window title only its icon (the title on hover); see Side-bar look in the Bar widgets settings to keep this on a top or bottom bar; popups and attached panels open beside the bar) | Top / Bottom / Left / Right | Top |
| Top bar | Bar thickness (its width on the left or right edge) | 28 – 72 px | 40 |
| Top bar | Top bar top margin | 0 – 100 px | 5 |
| Top bar | Top bar bottom margin | 0 – 100 px | 0 |
| Top bar | Top bar left margin | 0 – 300 px | 5 |
| Top bar | Top bar right margin | 0 – 300 px | 5 |
| Top bar | Bar style | Individual widgets (each pill has its own background) / Full bar (one background behind every widget, the pills' own go transparent) | Individual widgets |
| Top bar | Top bar opacity | 0 – 100 % (only in the Full bar style) | 60 % |
| Bar widgets (Layout tab) | The bar's layout, arranged by dragging (see below): a lane per zone of the bar (left, center, right) with its groups in bar order, each group one cell holding its widgets, and a lane of the widgets that are off. Drag a widget into a group to join it, between groups (or into an empty lane) to start a group of its own, or to Off to turn it off; drag a group by its handle (󰇛) to move it with its widgets and mode, or to Off; a line shows where the drop goes. Each group's button switches it between shown (󰈈), shown on hover (󰍽) and hidden (󰈉). The settings button can't be turned off | — | the original layout |
| Bar widgets (Settings tab) | Side-bar look, also on a top or bottom bar: CPU, RAM, Disk and Volume as a ring around their icon filled to their value, Network as a ring around each arrow filled to its speed against the last minute's highest (at least 1 MiB/s) (the figures move to their popup), Window title as its icon only (the title on hover); on a left or right bar they always look this way | on / off button for each | all off |
| Bar widgets (Settings tab) | Clock: date (each choice shown as today's date written that way, in the current language) | Long (Sunday, September 27, 2026) / Short (Sun, Sep 27) / Numeric (09/27/2026) / No date | Long |
| Bar widgets (Settings tab) | Clock: show seconds (without them the clock, and the bar, only update once a minute) | check box | on |
| Wallpaper | Wallpaper transition | Fade / None / From left / From right / From top / From bottom / Wipe / Wave / Grow / From center / To center / From anywhere / Random | Fade |
| Wallpaper | Transition duration | 0.5 – 10 s | 2 s |
| Theme | All themes: mode (dark or light: the Automatique palette, matugen's `--mode`, and the fixed themes that have a light version; for a light theme the olShell GTK theme is built on adw-gtk3 instead of adw-gtk3-dark, see [GTK](#gtk); disabled for a theme with no light version and for the custom theme) | Dark / Light | Dark |
| Theme | All themes: widget background (the color of the shell's widgets, popups and panels: for Automatique one of matugen's surface colors, `surface_container_lowest` to `_highest`, needing no matugen run; for the other themes their own, moved toward the background or the text) | Closest to the background / Close to the background / Normal / Raised / Most raised | Normal |
| Theme | Automatic theme: palette style (how matugen builds the palette from the wallpaper, its `--type`) | Tonal (calm) / Content (close to the wallpaper) / Fidelity (closest to the wallpaper) / Vibrant / Expressive / Fruit salad / Rainbow / Neutral / Monochrome | Tonal |
| Theme | Automatic theme: starting color (which of the wallpaper's colors the palette is built around: every color of it, not only the accent) | Most saturated / Most common / Least saturated / Darkest / Lightest | Most saturated |
| Theme | Automatic theme: contrast (matugen's `--contrast`; its values below 0 make the text too dim to read, so they're left out) | Standard – +100 % | Standard |
| Theme | Automatic theme: background lightness (matugen's `--lightness-dark` or `--lightness-light`, scaled to what stays usable in the mode: from about -0.1 to +0.2 in dark, -0.2 to +0.05 in light; further, the background and the pills turn the same pure black or white) | -100 % (darker) – +100 % (lighter) | Standard |
| Theme | Automatic theme: accent color (which of the palette's colors the shell uses as its accent, each shown in its color; the shell only, the other apps keep theirs, and it needs no matugen run) | Primary / Secondary / Tertiary | Primary |
| Theme | Fixed themes: accent color (the theme's own accents, as color dots; kept from one theme to the next by the color it is, e.g. purple is Catppuccin's mauve and Dracula's purple, and a theme without that color uses its own) | The theme's own / blue / purple / pink / red / orange / yellow / green / cyan, those the theme has | The theme's own |
| Theme | Fixed themes: exact colors in the other apps (a fixed or custom theme's apps get its background, text, widget, border and accent colors, instead of the palette matugen builds around its accent; see [Theming with matugen](#theming-with-matugen-automatique)) | check box | on |
| Theme | Custom theme: background, widget background, border, text and accent (typed as `#rrggbb`, or picked by clicking the color dot before each: a square of saturation and brightness for a hue picked on a bar, applied as you drag, or **From the screen**, which runs hyprpicker (`screenColorPicker` in [config/Apps.qml](config/Apps.qml)) to click a color anywhere, the settings panel hiding meanwhile and coming back where it was, with the picker closed; a mistyped color keeps the one there was), and **Copy its colors** (start from the theme in use) | any color | Catppuccin Mocha's |
| Theme | Other apps themed with the shell (with any theme; one turned off keeps the colors it last got, and turning one on colors it now; see [Theming with matugen](#theming-with-matugen-automatique)) | Hyprland / Zen / Alacritty / GTK / Qt / Starship, each on or off | all on |
| Theme | Other apps: added apps (each an app with a matugen template of your own: on / off, its name, the template file, the file matugen writes from it and a command run after, e.g. to reload the app; **Add** adds one and a bin removes it; an app without a template or an output file, or whose template can't be read, is left out of the runs instead of making them fail; the template uses matugen's syntax, and can use the shell's own data too, see [Theming with matugen](#theming-with-matugen-automatique)) | any | none |
| Notifications | Pop-up duration | 2 – 30 s | 4 s |
| Notifications | Pop-ups at once | 1 – 8 | 4 |
| Notifications | Notification position (a list of small screens with a block where the pop-ups go, and the name) | Top right / Top center / Top left / Right center / Left center / Bottom right / Bottom center / Bottom left | Top right |
| Notifications | Do not disturb | check box | off |
| OSD | Volume: position (a list of small screens with a block where the popup goes, and the name; also the volume pill on the lock screen) | Bottom center / Bottom left / Bottom right / Center / Left center / Right center / Top center / Top left / Top right | Bottom center |
| OSD | Volume: distance from the edge (from the edges it is placed against; at the top or bottom on the bar's side, from the bar; disabled while the position is Center) | 0 – 400 px | 60 px |
| OSD | Caps Lock / Num Lock: position | as for the volume | Bottom center |
| OSD | Caps Lock / Num Lock: distance from the edge (as for the volume) | 0 – 400 px | 60 px |
| Lock screen | Lock after (minutes without keyboard or mouse input) | never, 1 – 60 min | 8 min |
| Lock screen | Stay awake in fullscreen (while the focused window is fullscreen, a game or a film, the screen neither locks nor blanks by itself) | check box | on |
| Launcher | Default tab (the one the launcher opens on) | All / Applications / Games / Files / Web | All |
| Launcher | Results shown (the most the list shows at once, the launcher shrinking to fewer; more scroll) | 3 – 20 | 10 |
| Launcher | History length (the applications and games last opened from the launcher, listed first with an empty search; 0: none) | 0 – 10 | 3 |
| Launcher | Web search engines (on / off, name, address with `%s` where the search goes, order; add and remove) | any; the browser's default engine can be turned off and moved, not removed | the browser's default engine, YouTube, Wikipedia |
| Panels (Placement tab) | All panels: puts every panel in the place picked, changing each of the rows below it (which can then be changed one by one again); shows that place while they all share it, and **Different places** otherwise | the choices below | — |
| Panels (Placement tab) | Placement of each panel: launcher, settings, keyboard shortcuts, wallpapers, themes, power, notification actions, app switcher, clock, notification center, chat AI (a list of small screens with a block where the panel goes, and the name). Against the bar, the panel opens on the bar's screen (the one clicked, or the focused one when opened by a shortcut), flush with the bar, at that end of it or in its middle (on a left or right bar, "left" is its top end and "right" its bottom one, and the same along the opposite edge); halfway down the left or right edge, it sits as far from that edge as the bar is from it; against the opposite edge, it sits as far from that edge and from the sides as the bar is from its own (the bar's margins), mirroring it; centered, it opens over the screen | Center of the screen / Middle left / Middle right / Bar, on the left / Bar, in the middle / Bar, on the right / Opposite edge, on the left / in the middle / on the right | the bar's middle for the wallpapers, themes, power, clock, notification center and chat AI; the center of the screen for the others |
| Panels (App switcher tab) | direction (the windows in a column of rows, or side by side as cards) | Vertical / Horizontal | Vertical |
| Panels (App switcher tab) | windows shown (every window, those of the focused workspace, or those of the focused screen) | All / This workspace / This screen | All |
| Panels (App switcher tab) | one entry per app (its windows gathered, with how many there are as a badge on the icon's corner when more than one; the key above Tab, ² on a French keyboard, goes through the selected app's windows, Shift going back) | check box | off |
| Panels (App switcher tab) | shown with each window (under its icon on a card, beside it in a row): its title, and under it, a line each, its app and its workspace; each on or off, the card or row shrinking to what's left | Title / App / Workspace | all on |
| Panels (App switcher tab) | icon size | 24 – 96 px | 40 px |
| Panels (App switcher tab) | windows shown at once (rows or cards; more scroll, with an arrow and how many are out of view on each edge that has some) | 3 – 20 | 8 |
| Panels (App switcher tab) | switch when the shortcut is released (off: the switcher stays open, and Enter or a click switches) | check box | on |
| Panels (App switcher tab) | window pictures instead of icons (a live picture of each window on its card, its icon in a corner; only in the horizontal direction) | check box | off |
| Panels (Clock tab) | Tabs shown in the clock panel (with a single one, its tab bar is left out; with none, the agenda shows; nothing is fetched for the weather while its tab is off) | Agenda / Performance / Media / Weather / Clocks, each on or off | all on |
| Panels (Clock tab) | Weather: temperature unit (the wind in km/h or mph with it) | Celsius (°C) / Fahrenheit (°F) | Celsius |
| Panels (Clock tab) | Clocks: the places whose time the clocks tab shows, a row each with **Remove**, and **Add a place**: type a town and press Enter, and it's searched for (Open-Meteo's place search, as for the weather), which gives its time zone, and added at the end; the row says so if nothing was found | any | none |
| Panels (Clock tab) | Weather: place (a town or a place's name, e.g. `Lyon` or `Lyon, France`, searched for with Open-Meteo's place search; empty for automatic, from the internet address with ipinfo.io) | any | automatic |
| Chat AI | The tools the AI may use, each on or off: for files, list folders, find files, search in files and read files; for the web, search (Anthropic, OpenAI and xAI, billed per search) and read pages (Anthropic only). With none of the file tools it can't see your files, with none of the web ones it can't reach the web | List folders / Find files / Search in files / Read files; Search / Read pages | all on |
| Chat AI | The shell: read its documentation (this README, searched and read a part at a time) and its current settings, and run its commands (the IPC calls, all but those that can't be undone, see [Chat AI](#chat-ai)) | Read its documentation and settings / Run its commands | documentation on, commands off |
| Chat AI | Inclusion: what it can read besides the home folder, folders or files or wildcards (comma-separated, e.g. `/data, ~/*.md`; a bare name is looked for in the home folder) | any | none |
| Chat AI | History length (the questions the question box's ↑/↓ keys step through; 0: none) | 0 – 200 | 50 |
| Chat AI | Usage line along the bottom of the panel: what the last question used | on / off | on |
| Chat AI | Hint shown in the panel while it is empty, before a first question and after clearing it (how it works, its keys) | on / off | on |
| Chat AI | Icons in the panel's title showing which access options of the AI are on (its tools) | on / off | on |
| Chat AI | Exclusion: paths, file and folder names or wildcards it can't read, on top of the built-in secrets (comma-separated, e.g. `*.sqlite, ~/Private`) | any | none |
| Chat AI | Default provider (asked when the panel opens, until another is picked there; its model is the one on its own row) | a provider | the first provider that can be asked |
| Chat AI | Providers: Anthropic, OpenAI, xAI and Google (API key, model), and those added (name, address, API key, model; removable) | a model from the provider's own list | Anthropic, OpenAI, xAI and Google, no key |
| General | Language | Automatic / English / Français / Español | Automatic |
| General | Screenshot folder | an absolute path (`~` is your home folder), typed in | `~/Pictures/Screenshots` |

**The bar's layout.** The **Layout** tab of the **Bar widgets** category shows the bar as three lanes, **Left**, **Center** and **Right**, each holding its groups in bar order, and a lane of the widgets that are **Off** (launcher, settings button, workspaces, window title, clock, wallpaper, theme, screenshot, zoom and keyboard shortcuts buttons, tray, CPU, RAM, disk, network, network connection, Bluetooth, volume, notifications, lock, power, chat AI). The widgets of a pill are split into **groups** by dividers: a group starts at the first widget of a pill and at each widget with a divider before it, and is drawn as one cell holding its widgets. Drag a widget into a group to join it where you drop it, between groups (or into an empty lane) to start a group of its own there, or to **Off** to turn it off (turned on again from the IPC call, it goes back where it was); drag a group by its handle (󰇛) to move it, with its widgets and mode, anywhere in a lane, or to **Off** to turn all its widgets off. A line shows where the drop goes. Each group's button switches its mode: shown (󰈈), off and never shown (󰈉, its widgets stay in the group so it can be turned on again), or shown only on hover (󰍽): while the pointer is over its pill its widgets slide open, and shut again half a second after you leave it (the group of a widget whose popup is showing, such as the clock, stays open until the popup closes, so the popup keeps its anchor). A divider only shows when its widget does and something shown comes before it in the pill, so there is none at the start of a pill or for a widget with nothing to show (the window title when no window is open); a pill with nothing left in it disappears, a pill whose groups are all on hover keeps a small dots icon to hover, and a pill whose groups are all off is not drawn. By default there is a divider before every widget except the launcher, the settings button, the clock and the tray, which is how the bar looked before this was adjustable. The settings button can go anywhere but off, so this panel stays reachable by clicking. The layout is saved as three lists (`barLeft`, `barCenter`, `barRight`), the widgets with a divider before them (`barDividers`) and the widgets starting a group shown only on hover (`barCollapsed`) or off (`barGroupsOff`) in `config/Settings.json`; a widget listed twice or unknown is ignored.

Bar position picks which edge of the screen the bar is anchored to. Either way, the top and bottom margins keep their own meaning: whichever is on the side the bar is anchored to is the gap between the bar and that edge, and the other becomes extra room kept free on the far side of the bar (the bar reserves its height plus this much, so windows start that much further away), on top of your compositor's own gaps; at 0 the layout is what it was without the setting. Popups that open from the bar's own widgets (the clock, the tray, a widget's tooltip) open upward instead of downward when the bar is at the bottom, so they always open toward the middle of the screen. The text settings apply to all text and icons in the shell: the weight is what the font offers (a font without that weight uses the nearest it has), the outline is drawn in the accent color, and letter spacing and capitalization change the width of the text (so the bar's contents move). The settings are grouped in categories, shown as a column of buttons on the left of the panel, each an icon with its name (appearance, text, top bar, bar widgets, wallpaper, notifications, OSD, lock screen, launcher, panels, chat AI, general); click one to show its settings, whose name is the panel's heading. **Appearance** has three tabs under its name: **General** (the widgets' look, the gap and the curved joins), **Blur** (the blur and Hyprland's blur options) and **Windows** (Hyprland's window look, synced with the shell's on request). **Bar widgets** has two tabs under its name: **Layout** (the bar's layout, below) and **Settings** (the workspaces and zoom widgets' own settings, a section each); so does **Panels**: **Placement** (where each panel opens) and a tab for each panel with settings of its own, named after it (**App switcher**, **Clock**); click one, or press **Tab / Shift+Tab**, to switch.

The panel is 920 px wide, or wider (within the screen) when the widest row of the category needs it, as with the longer French names, so it follows the language, the font size and the font. A category with more rows than fit (the widgets, mostly) scrolls: with the wheel, or by moving the selection with the keys, which keeps it in view. Click or drag a slider (the font, the wallpaper transition and the pop-up position each open a list: click an entry to pick it, or scroll for more; the fonts are drawn in their own font, the positions with a small screen icon), or use the keys: **↑/↓** select a row, **←/→** adjust it (**Shift** for bigger steps), **Page Up/Page Down** switch category, **Tab/Shift+Tab** go through everything on the page one by one (each button, check box and field of a row, then the next row, around at the ends), **Ctrl+Tab/Ctrl+Shift+Tab** switch tab (in the categories that have tabs), **Enter** opens the list of a font, transition or position row (then **↑/↓**, **Page Up/Page Down**, **Home/End** move in it, **Enter** picks, **Escape** closes just the list); on the font style row, **←/→** move between the buttons and **Enter** (or **Space**) switches one, **Escape** closes. **Reset** (top right, next to the category's name) puts that category (or that tab) back to your own defaults, or to the built-in ones for any setting you saved none for. **Defaults:** the last row of each category (and of each tab) has two buttons: **Save as my defaults** remembers the category's current values as your own defaults (in `config/UserDefaults.json`, git-ignored; for the widgets category that is the whole bar layout, and for General the language too), and **Factory defaults** puts the category back to the built-in ones, whatever you saved, and saves them as your defaults too, so Reset then does the same: it first asks for a confirmation in the row itself (**Confirm** or **Cancel**; Cancel is the one the keys are on, and Escape cancels). The built-in defaults are in [config/Defaults.qml](config/Defaults.qml), which nothing writes to, so they are always there to go back to. On the keys, **←/→** move to a button and **Enter** presses it. The General category also has an **All categories** row with a **Factory defaults** button that does the same for every category and the language: it asks first (**Confirm** or **Cancel** in the row; Escape cancels), then puts everything back to the built-in values, saves them as your defaults and forgets where turned-off widgets were. (`settings factoryReset` does it from a script, without asking.) Neither the font size nor the icons (tray and active window) depend on the bar height, so a large font in a low bar can overflow the pills, and a very tall bar with big margins can make the bar's three groups collide.

Values live in [config/Settings.qml](config/Settings.qml), which `Theme` reads, so to make another value adjustable add it there (its built-in default in [config/Defaults.qml](config/Defaults.qml), limits, property), point `Theme` at it, and add a row (with its `category`) in [modules/Settings/SettingsPages.qml](modules/Settings/SettingsPages.qml) and its label in [config/Translations.qml](config/Translations.qml).

### From a script

Every call is `quickshell -p . ipc call settings <command> …`.

- `set <key> <value>`: a number setting (out-of-range values are clamped) or a yes/no one (1 or 0), keys below.
- `choose <key> <value>`: a setting with a list of choices (a value not in the list is ignored), a color or a text, keys below.
- `get <key>`, `getChoice <key>` (for the font family and capitalization too).
- `open <page>`: open the settings panel on a page, named as for `saveDefaults` (the categories below), or on a category with tabs by its first tab's name.
- `map`: the settings panel's map as JSON: its pages (id and name, as `Category > Tab`), each setting's page and name there, and each bar widget's name, in the current language.
- `reset`: every category, to your defaults.
- `saveDefaults <category>`: save a category's current values as your defaults.
- `restoreDefaults <category> <mine|factory>`.
- `factoryReset`: every category and the language, to the built-in values, without asking.
- The bar's layout:
  - `place <widget> <zone> [position]`: zone `left`, `center`, `right` or `off`; position from 0, or -1 for the end.
  - `widgetShown <widget> <1|0>`: put a widget on the bar, back where it was, or take it off.
  - `move <widget> <steps>`: negative for earlier.
  - `divider <widget> <1|0>`: the divider before a widget.
  - `group <widget> <on|hover|off>`: the mode of the group that widget is in.
  - `moveGroup <widget> <steps>`: move the group that widget is in earlier or later in its pill.
  - `layout`: prints the layout and dividers as JSON.

**Numbers** (`set`):

- `radius`, `opacity`, `spacing`, `borderWidth`, `panelGap`, `curvedJoinsRadius`
- `blurSize`, `blurPasses`, `blurVibrancy`, `blurContrast`, `blurBrightness`, `blurNoise`
- `windowBorderWidth`, `windowRounding`, `windowGapsIn`, `windowGapsOut`, `windowActiveOpacity`, `windowInactiveOpacity`
- `animationDuration`, `hyprlandAnimationDuration`
- `fontSize`, `fontWeight` (100 to 900, rounded to hundreds), `fontLetterSpacing`
- `barHeight`, `barMarginTop`, `barMarginBottom`, `barMarginLeft`, `barMarginRight`, `barOpacity`, `barAutoHideDelay`
- `workspaceCount`, `zoomMax`, `zoomStep`
- `wallpaperDuration`, `matugenContrast` (0 to 1), `matugenLightness` (-1 to 1)
- `notificationTimeout`, `notificationMax`, `volumeOsdMargin`, `lockKeysOsdMargin`, `lockTimeout`
- `launcherResults`, `launcherHistory`, `chatAiHistory`, `switcherIconSize`, `switcherMaxShown`

**Yes/no** (`set`, 1 or 0):

- `curvedJoins`, `curvedJoinsRadiusSame`, `borderOpaque`, `blurXray`
- `windowBorderSame`, `windowRoundingSame`, `windowGapsInSame`, `windowActiveOpacitySame`, `windowInactiveOpacitySame`
- `animations`, `hyprlandAnimations`, `hyprlandAnimationSame`
- `fontItalic`, `fontUnderline`, `fontOutline`
- `barAutoHide`, `workspaceCountFromHyprland`, `zoomBlocksInput`, `activeWindowIconOnly`, `clockSeconds`
- `cpuRing`, `ramRing`, `diskRing`, `volumeRing`, `networkRing`
- `matugenHyprland`, `matugenZen`, `matugenAlacritty`, `matugenGtk`, `matugenQt`, `matugenStarship`, `themeExactApps`
- `notificationDnd`, `screenshotEdit`, `lockStayAwakeFullscreen`
- `switcherGroupApps`, `switcherShowTitle`, `switcherShowApp`, `switcherShowWorkspace`, `switcherReleaseSwitch`, `switcherPreviews`
- `clockShowAgenda`, `clockShowPerformance`, `clockShowMedia`, `clockShowWeather`, `clockShowWorld`
- `chatAiListDir`, `chatAiFindFiles`, `chatAiSearchText`, `chatAiReadFile`, `chatAiWebSearch`, `chatAiWebFetch`, `chatAiShellDocs`, `chatAiShellIpc`, `chatAiShowUsage`, `chatAiShowHint`, `chatAiShowAccess`

**Choices** (`choose`):

| Key | Values |
|---|---|
| `themeMode` | `dark`, `light` |
| `themePill` | `lowest`, `low`, `normal`, `high`, `highest` |
| `themeAccent` | `default`, `blue`, `purple`, `pink`, `red`, `orange`, `yellow`, `green`, `cyan` |
| `matugenScheme` | `tonal-spot`, `content`, `fidelity`, `vibrant`, `expressive`, `fruit-salad`, `rainbow`, `neutral`, `monochrome` |
| `matugenSource` | `saturation`, `dominant`, `less-saturation`, `darkness`, `lightness` |
| `matugenAccent` | `primary`, `secondary`, `tertiary` |
| `fontCaps` | `none`, `upper`, `lower`, `small` |
| `barStyle` | `widgets`, `full` |
| `barPosition` | `top`, `bottom`, `left`, `right` |
| `hyprlandWindowStyle` | `config`, `popin`, `slide`, `gnomed` |
| `hyprlandWorkspaceStyle` | `config`, `slide`, `slidevert`, `fade`, `slidefade`, `slidefadevert` |
| `wallpaperTransition` | `fade`, `none`, `left`, `right`, `top`, `bottom`, `wipe`, `wave`, `grow`, `center`, `outer`, `any`, `random` |
| `screenshotMode` | `screen`, `region`, `window` |
| `notificationPosition` | `top-right`, `top-center`, `top-left`, `center-right`, `center-left`, `bottom-right`, `bottom-center`, `bottom-left` |
| `volumeOsdPosition`, `lockKeysOsdPosition` | `bottom-center`, `bottom-left`, `bottom-right`, `center-center`, `center-left`, `center-right`, `top-center`, `top-left`, `top-right` |
| `launcherPlacement`, `settingsPlacement`, `shortcutsPlacement`, `wallpaperPlacement`, `themePlacement`, `powerPlacement`, `notificationActionsPlacement`, `switcherPlacement`, `clockPlacement`, `notificationCenterPlacement`, `chatAiPlacement` | `center`, `center-left`, `center-right`, `bar-left`, `bar-center`, `bar-right`, `opposite-left`, `opposite-center`, `opposite-right` |
| `panelPlacement` | the same: sets every panel's placement at once; `getChoice` gives theirs when they all match, `each` otherwise |
| `launcherTab` | `all`, `apps`, `games`, `files`, `web` |
| `switcherOrientation` | `vertical`, `horizontal` |
| `switcherScope` | `all`, `workspace`, `monitor` |
| `weatherUnit` | `celsius`, `fahrenheit` |
| `clockDate` | `long`, `short`, `numeric`, `none` |

**Colors and text** (`choose`):

- `customBackground`, `customPill`, `customBorder`, `customText`, `customAccent`: a `#rrggbb` color.
- `weatherLocation`: a place's name (`""` for automatic).
- `chatAiDefaultProvider`: a chat AI provider's id (`anthropic`, `openai`, or an added one's), `""` for the first one that can be asked.
- `fontFamily`: any installed font family, e.g. `settings choose fontFamily "DejaVu Sans Mono"`. The panel's list only has the Nerd Font families, since the icons are Nerd Font glyphs. Qt only reads the installed fonts when the shell starts, so restart the shell after installing or removing one.

**Widgets** (`place` and the other layout calls): `launcher`, `settings`, `workspaces`, `activeWindow`, `clock`, `wallpaper`, `theme`, `screenshot`, `zoom`, `shortcuts`, `tray`, `cpu`, `ram`, `disk`, `network`, `connection`, `bluetooth`, `volume`, `notifications`, `lock`, `power`, `chatAi`.

**Categories** (`saveDefaults`, `restoreDefaults`): `appearance` (its General tab), `blur` (its Blur tab), `windows` (its Hyprland tab), `appOpacity` (its App opacity tab), `animations` (the Animations category's General tab), `hyprlandAnimations` (its Hyprland tab), `text`, `bar`, `layout` (the Layout tab), `widgetSettings` (the Settings tab), `wallpaper`, `theme`, `notifications`, `osd`, `lock`, `launcher`, `chatAi` (the Chat AI category's Providers tab), `chatAiAccess` (its Access tab), `chatAiHistory` (its Miscellaneous tab), `panels` (its Placement tab), `switcher` (its App switcher tab), `clockPanel` (its Clock tab), `general`.

The wallpaper transition and its duration apply the next time a wallpaper is applied (they are the `awww img` `--transition-type` and `--transition-duration`), including when the shell restores the last one at startup.

## Localization

The shell speaks **English**, **French** and **Spanish**. By default it follows the system language (`LC_ALL`, `LC_MESSAGES` or `LANG`; English if that isn't one of them). The language can be chosen in the settings panel (General), and the choice is remembered in `config/LocaleState.json` (git-ignored). It can also be set from a key binding or a script (`toggle` goes to the next language, English → French → Spanish):

```sh
quickshell -p . ipc call language set es      # or en, fr, or auto to follow the system again
quickshell -p . ipc call language toggle
quickshell -p . ipc call language get
```

Everything is switched at once: texts, dates and month/day names, decimal separators, and units (Gio / GiB). The week still starts on Monday in both.

The launcher's application names, descriptions and keywords follow the shell's language too, not the system's: every `.desktop` file carries all its translations (`Comment[fr]=...`), so [services/DesktopLocale.qml](services/DesktopLocale.qml) reads them straight from the files (the user's and system's `applications` directories, in priority order) and picks the best one for the current language (`language_COUNTRY`, then `language`, then the untranslated text), instead of the single language Quickshell reads at startup. Searching matches the translated name and keywords as well as the untranslated name ("files" still finds Fichiers). The files are read again each time the launcher opens; an application with no readable file falls back to Quickshell's own text.

The texts are in [config/Translations.qml](config/Translations.qml), one dictionary per language with dotted keys (`power.logout`); [config/I18n.qml](config/I18n.qml) looks them up with `I18n.tr("key", args...)`, replacing `{0}`, `{1}`... and choosing between `one` / `other` forms for counts. A key missing from a language falls back to English, then shows the key itself. To add a language: add a dictionary with the same keys as `en` (including `format.locale`, `format.decimal`, `format.units`, `format.date.long`, `format.date.short`, `format.date.numeric`, `format.time`, `format.timeSeconds`) and list its code in `I18n.supported`. Use `I18n.tr` for any new visible text rather than a literal.

## btop

Clicking the CPU, RAM or network-speed widget opens btop in a terminal window showing only that widget's box (its **cpu**, **mem** or **net** box), and clicking again closes it. The same from a key binding: `quickshell -p . ipc call btop cpu` (or `memory`, `network`); `quickshell -p . ipc call btop toggle` opens the full btop, with the boxes of your own configuration, which no widget does. A single-box window is smaller (50% × 50% of the monitor; `btopBoxWidth` and `btopBoxHeight` in [config/Apps.qml](config/Apps.qml)); the full one is 85% × 90%. The box is chosen by setting `shown_boxes` in the copy of your `btop.conf` described below (for the memory box, `show_disks` is turned off too, since btop would draw the disks inside it; see `boxSettings` in [services/Btop.qml](services/Btop.qml)), so your own configuration and its layout are not touched. There is one btop window, so a click on another widget while it is open closes it instead of switching to that widget's box. [services/TuiWindow.qml](services/TuiWindow.qml) (shared with the gdu window, below) launches the terminal through Hyprland with launch-time window rules (floating, centered, sized to a fraction of the focused monitor), so nothing needs adding to your Hyprland config. The window has its own class (`quickshell-btop`), which is how the toggle finds it to close it, even after a shell reload.

The window is themed with the shell's current colors: [scripts/tui-launch.py](scripts/tui-launch.py) generates a btop theme from the palette (background, text, accent, outline) each time it opens, plus a copy of your `btop.conf` that selects it, in `$XDG_RUNTIME_DIR/quickshell-btop/`, and starts the terminal with matching colors (for alacritty). Your own `~/.config/btop/btop.conf` is never modified; settings you change inside this btop are saved to the copy, and it picks up the theme that's active when it's opened.

It is a real terminal window, so btop works completely (mouse, copy/paste, resizing) but it's an ordinary window: no dimmed backdrop, and clicking elsewhere or pressing Escape doesn't close it. The terminal and size (as fractions of the monitor, 85% × 90% by default) are in [config/Apps.qml](config/Apps.qml) (`btopTerminal`, `btopWidth`, `btopHeight`); another terminal works too, but only alacritty gets the colors applied (btop itself is themed either way).

## Audio mixer

Clicking the volume widget opens [pavucontrol](https://freedesktop.org/software/pulseaudio/pavucontrol/), and clicking again closes it (whichever way it was opened); a middle click mutes or unmutes the output (the OSD shows it). It's an ordinary window of its own, in the shell's colors through the olShell GTK theme (see [GTK](#gtk)). Scrolling over the volume widget adjusts the volume.

The btop window is as translucent as the widgets (the **Widget opacity** setting, read each time a window opens), so Hyprland blurs what's behind them if its blur is enabled. To make that possible the applications don't paint a background of their own (btop's `theme_background` is turned off in the copy of its config) and the terminal window's opacity is set to the widget opacity, overriding your terminal's own setting (only alacritty is handled, as for the colors).

## gdu

Clicking the disk widget (or `quickshell -p . ipc call gdu toggle`) opens [gdu](https://github.com/dundee/gdu), an interactive disk usage analyzer, on the disk mounted on `/`, and clicking again (or the same call) closes it. It shows which folders take the room, largest first: **Enter** goes into a folder, **←** back out, **d** deletes the selected item (with confirmation), **?** lists the other keys. (btop can't be used for this: it draws the disks inside its memory box, and nothing hides the memory part.) The window works like the others: [services/TuiWindow.qml](services/TuiWindow.qml) opens it floating and centered (60% × 70% of the monitor by default) with its own window class (`quickshell-gdu`), as translucent as the widgets.

gdu is started with `--no-cross`, so it stays on the filesystem of `/` (other disks and mounts such as `/boot/efi` aren't counted, as the widget doesn't count them; note that on btrfs, subvolumes such as `/home` count as other filesystems, so remove `--no-cross` in [scripts/tui-launch.py](scripts/tui-launch.py) there). It reads its styles from a file the launcher writes, `$XDG_RUNTIME_DIR/quickshell-gdu/gdu.yaml`, with the shell's colors for the header, footer, selected row and directories; that replaces gdu's default `~/.gdu.yaml` for this window only, so a configuration of yours is not used here (and never modified). The terminal and size are in [config/Apps.qml](config/Apps.qml) (`gduTerminal`, `gduWidth`, `gduHeight`).

## Launcher

The apps icon in the middle of the bar, or `quickshell -p . ipc call launcher toggle` (bind it to a key), opens a search box over the installed applications (their `.desktop` entries; one that runs in a terminal, such as yazi or htop, opens in `appTerminal` from [config/Apps.qml](config/Apps.qml), alacritty by default, in a floating window centered on the focused monitor, sized by `appTerminalWidth` and `appTerminalHeight` there). Type to filter: matches names first (exact, prefix, word prefix, anywhere), then generic name, keywords, category and description, and finally letters in order (`ffx` finds Firefox). **Tab / Shift+Tab** switch tabs (keeping what you typed; so do **Alt+1…5** and a click); **↑/↓**, **Ctrl+N / Ctrl+P** (or **Ctrl+J / Ctrl+K**) and **Page Up / Down** move the selection, **Enter** launches it, **Escape** or a click outside closes. Hovering moves the selection too and a click launches; resting the pointer on an entry for half a second shows a tooltip with the real process name (e.g. "Fichiers" → `nautilus`), its full command and its desktop-entry id. With an empty search the list is alphabetical, after the applications (and games) last opened from the launcher, the latest first and selected, so **Enter** opens it again; how many is the **History length** setting of the **Launcher** category (`launcherHistory`, 0 to 10, 3 by default; 0 turns it off), and the history is remembered across restarts (`config/LauncherState.json`). The **All** tab groups what it finds under headings: the best applications, then the best games (the Games tab's, left out of its applications), files and the web; with an empty search, the ones last opened under **Recently opened**, then every other application, then every other game. The web tab opens what you typed if it looks like an address, then offers a search with each web search engine set in the settings' **Launcher** category, in their order: by default the default browser's own default engine, then YouTube and Wikipedia; the web section of the All tab has the same. There each engine has a row with a check box (offered or not), its name and its address (click one, or press **Enter** on it, to type in it; **Enter** saves, **Escape** cancels; an address must start with `http://` or `https://` and have `%s` where the search goes, or the field stays open), ‹ › arrows to move it and a bin to remove it; on the keys, **←/→** move between these and **Shift+←/→** move the engine. **Add** (the row under them) adds one and starts typing its name. The browser's engine can be turned off and moved but not removed; its row names the engine found. The list is `launcherEngines` in `config/Settings.json`, and from a script: `settings engines` (prints it as JSON), `settings addEngine <name> <url>`, `settings removeEngine <index>`, `settings moveEngine <index> <steps>` and `settings engineOn <index> <1|0>` (index from 0, in the list's order). The apps added to the themed apps (settings' **Theme** category) go the same way: `settings matugenApps` (prints them as JSON), `settings addMatugenApp <name> <template> <output> <command>` (`""` for no command), `settings removeMatugenApp <index>` and `settings matugenAppOn <index> <1|0>`. The apps with an opacity of their own (Appearance's **App opacity** tab) too: `settings appOpacities` (prints them as JSON), `settings setAppOpacity <class> <focused> <not focused>` (Hyprland's window class, opacities from 0.1 to 1; adds the app if it has none yet) and `settings linkAppOpacity <class> <focused 1|0> <not focused 1|0>` (follow the general window opacity, or not) and `settings removeAppOpacity <class>`. The browser's default engine is read from the browser's profile each time the launcher opens by [scripts/default-search-engine.py](scripts/default-search-engine.py), for Firefox and the browsers built on it (Zen, LibreWolf, Floorp, Waterfox) and for the Chromium-based ones. When it can't be read (another browser, or a built-in engine the script doesn't know), DuckDuckGo is used in its place (`webSearchFallback` in [config/Apps.qml](config/Apps.qml)). The **Games** tab lists only the applications in the Game category (`Categories=Game;` in their desktop entry): the games' shortcuts made by Faugus, Heroic or Steam, and other games installed as applications; a game without a desktop entry doesn't show. The launchers and tools that put themselves in that category too (Steam, Heroic, Faugus, GOverlay) are left out: `notGames` in [config/Apps.qml](config/Apps.qml), by desktop entry id (the file name without `.desktop`), lists them. The settings panel's **Launcher** category sets the tab it opens on (`launcherTab`) how many results it shows at once at most (`launcherResults`, 3 to 20; the rest scroll) and how many recently opened applications it lists first (`launcherHistory`). The launcher is as tall as the results it shows, up to that many, and its top stays put as it grows and shrinks.


## App switcher

`quickshell -p . ipc call switcher toggle` opens a panel listing Hyprland's open windows, the most recently focused first, each with its icon, title, app and workspace, and the previously focused one selected. **↑/↓**, **Tab / Shift+Tab** (or **←/→**) move the selection, **Enter** or a click switches to the window (on its workspace), **Escape** or a click outside closes. It is placed like the other panels (the settings' **Panels** category, `switcherPlacement`), and lists the windows in a column of rows or side by side as cards, each a large icon (or a live picture of the window) with the title and, a line each, the app and workspace under it (on a card the title wraps onto two lines before it's cut). The **App switcher** tab of that category sets its direction, which windows it lists (all, the focused workspace's or the focused screen's), whether it gathers them by app (the key above Tab, ² on a French keyboard, then goes through the selected app's windows), what it shows with each window (title, app, workspace), its icon size, how many windows show at once before it scrolls, whether releasing the shortcut switches, and the pictures (see the table above).

Bound to a shortcut in the Hyprland config, e.g. `hl.bind("SUPER + TAB", hl.dsp.exec_cmd("qs ipc call switcher toggle"))`, it works like Alt+Tab with that shortcut, whatever it is: it finds the shortcut in the config each time it opens (with [scripts/list-shortcuts.py](scripts/list-shortcuts.py)), then pressing it again while holding its modifier moves on (with **Shift** added, back), and releasing the modifier switches to the selected window. So `toggle` only closes it when its shortcut has no modifier; otherwise **Escape** does, or `switcher close`.

`switcher next` and `switcher prev` step the same way (the first opens it on the previously focused window, the second on the last one), for binds of your own; releasing Super, Alt or Ctrl switches then, or the `toggle` shortcut's modifiers once it is known. The panel only sees that release once it has the keyboard, so a very quick press can be over before it does: bind `switcher confirm`, which switches to the selected window, to the modifier's release in Hyprland too.

## Keyboard shortcuts

`quickshell -p . ipc call shortcuts toggle` (bind it to a key) opens a panel centered on the screen listing the shortcuts of the Hyprland config that use the **Super** key, keyboard and mouse (media keys, Print Screen and other keys without Super are left out), grouped (applications, shell, windows, workspaces) and described in the shell's language: "Go to workspace 1", "Open the launcher" for a shell IPC call, "Open zen-browser" with its full command under it. Type to filter (keys, description or command); **↑/↓** and **Page Up / Down** scroll, **Escape** or a click outside closes. A bind's own `description` option, if it has one, is shown instead.

A Lua config binds each shortcut to a Lua function, so Hyprland itself (`hyprctl binds`) only knows its keys: [scripts/list-shortcuts.py](scripts/list-shortcuts.py) reads what they do from the config's `hl.bind(...)` calls instead, each time the panel opens, following its `require(...)`s and resolving its string variables (`terminal`, `mainMod`...). Binds it can't read (built in a loop, say) are counted against Hyprland's own list of Super binds, and the panel says how many are missing.
## Chat AI

`quickshell -p . ipc call chatai toggle` (bind it to a key), or the chat AI widget (󰭹, off by default: turn it on in the bar's **Layout** tab), opens a panel for one question to an AI and its answer: no conversation, each question starts afresh. Type the question and press **Enter**; the files the AI lists, searches and reads to answer show under it as it works, then its answer, in Markdown (its text can be selected; its links open in the browser, and its paths, absolute or from `~`, in `code` or not, are links too: a click on a folder opens it in the default file manager, and on a file opens it with the default application for its type (`gio open`, which falls back on the type's parents, so a Python script opens in the text editor); a file with no application for its type, or one its application would run rather than show (programs, `.desktop` launchers, Windows programs through Wine, AppImages, Java archives, shell scripts), is shown selected in its folder instead, through the file manager's `org.freedesktop.FileManager1` D-Bus interface as a browser's "Show in folder" does, or else its folder opens; a path that no longer exists opens its folder; each path is followed by a folder icon (󰉋), and each image of this computer has one in its corner, which always shows it selected in its folder in the file manager; resting the pointer on a link shows where it leads in a tooltip; opening a file, a folder or a web page closes the panel, out of the way), with its images: the AI is told to write one as `![description](path or address)`. An image on this computer (an absolute path, from `~` or `/`) shows at once, as wide as it is up to the panel's width and at most 420 px tall, and a click opens it; one from the web shows as a placeholder naming its site until you click it, since loading an image sends its address to that site, and a page the AI read could have it write one holding what it read from your files. the button at the top right ("Anthropic · Claude Sonnet 5.5"), or **Ctrl+M**, opens a menu of the providers that can be asked with the models each one lists, the one asked ticked and each provider's default (its **Default model** in the settings) marked *default*: **↑/↓** and **Page Up / Down** move, **Enter** or a click picks, **Escape** closes just the menu. A model picked there is asked in place of that provider's default until the shell restarts, without changing the setting; picking the default again goes back to it. A row of icons left of those buttons (the **Access icons in the title** setting turns it off) shows the AI's access options of the settings' **Access** tab, one each for listing folders, finding files, searching in files, reading files, the web search, reading web pages and the shell's documentation and its commands (not the inclusion and exclusion, which are lists): in the accent color when it is on, crossed and dimmed when it is off or the provider asked can't do it (the web search needs a provider with a web search tool), with which one and why on hover, the one for reading pages only being there with Anthropic; it is about the provider, so a model of it that refuses the search tool is only found out when asked. Once another provider or model is picked, a **Default** button appears left of the top right button and goes back to the default provider and its default model at once. **Tab / Shift+Tab** switch the provider asked, **↑/↓** step back and forward through the last questions (**History length** in the chat AI settings, 50 by default) in the question box (what was typed comes back at the end), **Page Up / Down** scroll the answer, **Ctrl+Shift+C** (or the copy button under it) copies the whole exchange (question, what the AI looked at and answer); the question, the answer and any error can also be selected with the mouse, a line along the bottom of the panel gives what the question used (tokens sent and received, with those read from the provider's cache and spent reasoning when there were any, the web searches and the requests when it took several), as the provider reports it, saved with the answer (the **Usage line** setting turns it off), the button at the end of the question box stops a question being answered, **Escape** or a click outside closes. Closing doesn't stop it: the answer is there when the panel opens again. The last question and its answer (with the files looked at, or the error) are saved in `config/ChatAiState.json` (git-ignored) once answered, and show again after the shell restarts, until the next question replaces them or the **Clear** button under the answer (or `chatai clear`) forgets them. The panel is as tall as what it shows, growing with the answer up to all the room the screen has for it: the screen's height less the bar, with the **Gap** of the Appearance settings between it and the bar and between it and the screen's edges; a longer answer scrolls. `chatai selectModel <provider> <model>` picks the model asked the same way (`""` for the default), `chatai selectDefault` goes back to the default provider and its model, and `chatai ask "<question>"` asks from a script (it opens the panel), and `chatai answer` prints the last answer.

The request runs in [scripts/ai-ask.py](scripts/ai-ask.py) (standard library only), which gives the AI four tools, all read-only: list a folder, find files by name (`fd`), search text in files (`ripgrep`) and read a text file (400 lines at a time). None of them writes a file or runs a command the AI chooses. They reach the home folder and the **Inclusion** of the settings, never outside (every path is resolved first, symbolic links and `..` included), and never the built-in secrets: `~/.ssh`, `~/.gnupg`, the keyrings, password stores, cloud and AI tools' credentials, browser and mail profiles, shell histories, `~/.cache`, and any file or folder named like `.env*`, `*.pem`, `*.key`, `id_rsa*`, `*secret*`, `*token*`, `*credential*`, `*cookie*`... (the full list is at the top of the script), plus what **Exclusion** adds. Whatever the AI reads is sent to the provider, so hide what it shouldn't see there. Each of these tools can be turned off in the settings' **Chat AI** category (**Files**: List folders, Find files, Search in files, Read files), and a tool that is off is refused even if the model asks for it. With the **Web** tools on (**Search** and **Read pages**, on by default) and Anthropic asked, it can also search the web and read pages with Anthropic's own web search and web fetch tools, which run on Anthropic's servers (with OpenAI asked, it can search the web, but not read pages, as described below): at most 5 searches and 5 pages per question, each search billed by Anthropic (and the organization's web search must not be turned off in its Console). The searches and pages show in the panel as the files do, and the pages the answer cites are listed under it. Web fetch only opens the addresses the searches found or the question gives, never one the model makes up, so a page it reads can't have it send your files' content to an address of its author's. A model without the newest versions of these tools gets the basic ones, and one without either answers without the web. OpenAI and xAI are asked through their Responses API instead of Chat Completions (for their own APIs only: it is the one with a web search tool, and it lets the tools and the model's reasoning go together): with **Search** on, they can search the web with the provider's built-in web search tool, billed by it per search (a model that refuses the tool is asked again without it), its searches and the pages it opens showing in the panel as Anthropic's do, and the pages it cites listed under the answer; they have no separate tool to read pages, so **Read pages** only applies to Anthropic. Google and added providers have no web tools.

The AI also knows about the shell itself, with the **The shell** tools of the settings (these work with every provider). **Read its documentation and settings** (on by default) lets it search this README and read it a part at a time: a search gives each matching line's number and section with only the text around the match, since a paragraph here is one long line, and a read gives the table of contents, a section by its heading, or a few lines, so it can answer how to do something, what a setting does or which key opens what, without the whole file sent to the provider. It also reads how the shell is set now: every setting's value (from `config/Settings.json`) with where it is in the settings panel (from `settings map`, so it names pages and rows as the panel shows them, and opens the right one), where each bar widget is (its lane, its group, and whether that group shows, shows only on hover or is off), the theme and wallpaper picked and the language, and is told to check the item a question is about, so its answer fits your shell ("your bar is at the top: to move it...") rather than the defaults. It reads the README and settings of the shell that is running (this checkout, or the deployed copy). **Run its commands** (off by default) lets it act on the shell through its IPC calls, as `quickshell -p <the shell's folder> ipc call ...` would: it lists the calls the running shell has, then runs those the question asks for (change a setting, move a widget, open a panel, change the volume, take a screenshot...), each shown in the panel as it runs, and says in its answer what it changed. When the question only asks about something (how to change the theme, where a panel opens), it answers, then offers up to three buttons under the answer for the next step: open the panel it's about, open the settings on the page with its setting, or set the setting to what you seem to want. Each button shows its label and, beside it, the call it runs; a click runs it, and the button then shows ✓ with what the call gave, or ✗ with why it failed. The buttons are saved with the answer, and can't be clicked while **Run its commands** is off. Some calls are kept for you, refused even if the model asks: logging out, restarting, shutting down, suspending and the firmware restart (`power`, all but `toggle`), locking the screen (`lock lock`), putting settings back or saving them as defaults (`settings factoryReset`, `reset`, `restoreDefaults`, `saveDefaults`), and the chat's own `chatai` calls; the list is `IPC_BLOCKED` in the script. A call that opens another panel closes this one, as any panel does; the answer is there when it opens again.

The providers are set in the settings' **Chat AI** category, in its **Providers** tab (its other tabs are **Access**, for the tools and what they reach, and **Miscellaneous**, for the question history and the usage line). **Anthropic**, **OpenAI**, **xAI** and **Google** are built in, their API and address fixed (xAI speaks the same APIs as OpenAI, at `https://api.x.ai/v1`; Google's Gemini speaks OpenAI's Chat Completions API, at `https://generativelanguage.googleapis.com/v1beta/openai`, with no web search): each has a row with a field for its API key, and one for its model. A saved key is only replaced or removed once confirmed. Once a key is entered, the provider's models are read from its API (for OpenAI, only those that can answer through its Chat Completions API: not speech, pictures or embeddings), the newest first, and the newest is picked until you pick another from the **Default model** list; until then the list says why it is empty (no key, loading, or the provider's error). A provider can be asked once it has a key; the **Default provider** of the settings (the first one that can be asked, if none is set or it can't be asked yet) is asked when the panel opens, until another is picked there. **Add** (under the default provider, above them) adds a provider speaking the OpenAI-compatible Chat Completions API, with its name, its base address, ending with the version (`https://api.mistral.ai/v1`, `https://openrouter.ai/api/v1`, `https://generativelanguage.googleapis.com/v1beta/openai` for Gemini, `http://localhost:11434/v1` for Ollama...), its key and its model, likewise listed from its API; an added provider can be asked without a key (a local server needs none), and the bin removes it. The keys are saved in the secret keyring with `secret-tool` (under `service olshell-ai provider <id>`: `anthropic`, `openai`, or the id given to an added provider; in the default collection, or the first one that outlives the session when there is none) by [scripts/ai-key.py](scripts/ai-key.py), never in `config/Settings.json` or on a command line: the field shows only whether one is saved; type a key and press **Enter** to save it, or save it empty to remove it. Replacing or removing a key already saved asks first, in the row itself (**Confirm** or **Cancel**; Cancel is the one the keys are on, and Escape cancels); the new key is only held until you answer, and an empty field with no key saved changes nothing. Removing a provider removes its key. The list is `chatAiProviders` in `config/Settings.json` (`{ "builtin": "anthropic", "model": ... }` for a built-in one, `{ "id", "name", "url", "model" }` for one added); `chatai providers` prints it as JSON, with whether each has a key and its models. When the keyring is locked, saving or reading a key opens GNOME Keyring's own password prompt (`gcr-prompter`, from the `gcr` package, which GNOME Keyring needs for it), an ordinary window: whichever shell panel is open steps aside while it's open, the prompt gets the keyboard, and the panel comes back as it was once the prompt closes ([services/KeyringPrompt.qml](services/KeyringPrompt.qml)). Logging in with your password unlocks the `login` keyring through PAM (`pam_gnome_keyring.so`), so the prompt doesn't show.

## Themes

The theme panel (palette icon in the bar, or the IPC call below) lists **Automatique**, ten fixed themes (Catppuccin, Dracula, Nord, Gruvbox, Tokyo Night, Solarized, One, Rosé Pine, Everforest and Kanagawa) and **Custom**. Each card shows its theme as it would be used, with the settings' mode, accent and widget background. The **Automatique** button in the top-right corner jumps to its card and applies it. Left/Right browse; **Enter** or a click applies; **Escape** or a click outside closes. The choice is saved in `config/ThemeState.json` (git-ignored) and restored on startup.

- **Automatique** uses the palette matugen generates from the current wallpaper (below).
- A fixed theme ignores the wallpaper, which is only remembered for when you switch back to Automatique. Each has a dark version and, when the theme has an official one, a light version, used when the settings' **Theme** mode is Light: Catppuccin Mocha / Latte, Gruvbox Dark / Light, Tokyo Night / Day, Solarized Dark / Light, One Dark / Light, Rosé Pine / Dawn, Everforest Dark / Light and Kanagawa / Lotus (Dracula and Nord are dark only). Its accent is one of the theme's own accents, picked in the settings by the color it is (blue, purple, pink, red, orange, yellow, green, cyan), so it stays a purple accent, say, from one theme to the next; a theme without that color uses its own default.
- **Custom** uses the five colors set in the settings' **Theme** category (Custom theme), typed as `#rrggbb` or picked with the color picker their dot opens; **Copy its colors** starts them from the theme in use. It is as light or as dark as its background.

To add or edit a theme, change the list in [config/ThemePresets.qml](config/ThemePresets.qml): each version defines four of the five colors of [matugen/quickshell-theme.json.template](matugen/quickshell-theme.json.template) and its accents, by color name, with the default one. The palettes are the themes' published colors, as they were written in; check them against the theme's own page before relying on one.

## Theming with matugen (Automatique)

Colors come from `config/GeneratedColors.json`, which matugen writes from the current wallpaper. The file is git-ignored; until it exists, the defaults in [config/GeneratedColors.qml](config/GeneratedColors.qml) are used.

[matugen/quickshell.toml](matugen/quickshell.toml) is a dedicated matugen config holding this shell's templates (its palette, and the colors of Hyprland, [Zen](#zen-browser), [alacritty](#alacritty), [GTK](#gtk), [Qt](#qt) and starship), so applying a wallpaper or a theme doesn't also re-theme every app in your global `~/.config/matugen/config.toml`. [services/Matugen.qml](services/Matugen.qml) runs it:

- applying a wallpaper regenerates everything from it when **Automatique** is selected; a fixed theme ignores the wallpaper, which is only remembered;
- selecting a theme regenerates everything: from the wallpaper for **Automatique**, or from the theme's accent color for a fixed or custom one, in the theme's mode (light for a light version). With **Exact colors in the other apps** on (the default), the apps' templates then use the theme's own background, text, widget, border and accent colors for those roles, and matugen's palette around the accent only for the others (the terminal's ANSI colors, error, ...), so they match the shell exactly;
- changing a setting of the settings' **Theme** category the colors are made from regenerates everything, a second after the last change (so dragging a slider runs matugen once, not at every step), unless the colors are back to what they were made with: the mode, the Automatic theme's palette style, starting color, contrast and background lightness, a fixed theme's accent and widget background, the custom theme's colors, and **Exact colors in the other apps**. A fixed theme's apps get matugen's default style around its accent, whatever the Automatic theme's style. The Automatic theme's accent and widget background need no run: `config/GeneratedColors.json` holds every candidate and the shell picks from them;
- adding an app in the settings' **Theme** category (Other apps), with its template and output file, or changing or turning on an added one, also regenerates everything; the script writes a `[templates.addedN]` section for each in `matugen/active.toml`;
- turning an app on in the settings' **Theme** category (Other apps) regenerates everything, with any theme, so it gets the current colors now; one turned off is left out of the runs (the shell runs matugen through [scripts/matugen-run.py](scripts/matugen-run.py), which writes `matugen/active.toml` without the other apps' templates) and keeps the colors it last got. Turning Hyprland off also means a run no longer makes Hyprland reload its config;
- restoring the last wallpaper when the shell starts only regenerates the colors if the theme, the wallpaper or its file, or the Automatic theme's settings changed since the last run (remembered in `config/ThemeState.json`): rewriting `~/.config/hypr/colors.lua` makes Hyprland reload its config, which would otherwise happen on every start of the shell for nothing. `ipc call wallpapers applyLast` always regenerates them.

A fixed theme has no image, only five colors, so matugen builds a full palette around its accent: the apps get colors in the theme's family, not its exact palette (Dracula's purple accent gives a purple-tinted dark background, not Dracula's own `#282a36`). The shell itself always uses a fixed theme's exact colors. Every run also rewrites `config/GeneratedColors.json`, which **Automatique** reads: while a fixed theme is selected it holds that theme's palette, so the "Automatique" card of the theme panel previews those colors, not the wallpaper's, and selecting **Automatique** regenerates it from the wallpaper (the shell shows the previous palette until matugen has finished, about a second). The last wallpaper is remembered in `config/ThemeState.json` for that; until a wallpaper has been applied once, that state is empty and selecting **Automatique** regenerates nothing.

The config is used straight from the checkout, with template paths relative to the file, so nothing has to be copied into `~/.config/matugen` and the checkout can live anywhere. Don't also declare these templates in your global `config.toml`, or a plain `matugen image …` would write them a second time.

A template for an app added in the settings is any file in matugen's template syntax: `{{colors.primary.default.hex}}` is replaced with the palette's primary color, `{{colors.background.default.hex}}` with its background, and so on (see matugen's documentation for every color and format). To follow **Exact colors in the other apps** like the built-in templates, write a role as `<* if {{olshell.exact}} *>{{olshell.background}}<* else *>{{colors.background.default.hex}}<* endif *>`: the shell passes a fixed or custom theme's own colors as `olshell.background`, `text`, `textVariant`, `pill`, `pillLow`, `pillHigh`, `border`, `accent` and `onAccent` (the header of [matugen/quickshell.toml](matugen/quickshell.toml) lists them). The command after runs through the shell once the file is written, e.g. to have the app reload it.

## Zen browser

[matugen/quickshell.toml](matugen/quickshell.toml) also has a template, [matugen/zen-theme.css.template](matugen/zen-theme.css.template), which colors [Zen browser](https://zen-browser.app)'s interface — tabs, sidebar, URL bar, panels and the window background — with the theme the shell is using, so the browser follows the wallpaper and theme changes along with the bar. Turn Zen off in the settings' **Theme** category (Other apps) if you don't use it. Zen follows its own light or dark mode, whatever the Automatic theme's mode: the template gives it both variants of each color.

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

Alacritty reloads imported files while it runs, so open terminals recolor as soon as the wallpaper or theme changes, with no restart (unlike [Zen](#zen-browser)). Turn alacritty off in the settings' **Theme** category (Other apps) if you don't use it. The same goes for Hyprland (writes `~/.config/hypr/colors.lua`) and starship (writes `~/.config/starship/starship.toml`, **replacing** that file: keep your prompt's layout in the template). The btop and gdu windows the shell opens set their own colors from the shell's theme and don't use this file.

## GTK

[matugen/gtk-theme.css.template](matugen/gtk-theme.css.template) only defines the GTK named colors (window, view, header bar, sidebar, card, dialog and popover backgrounds, accent, ...) from the shell's palette; GTK builds the widgets from them. [matugen/quickshell.toml](matugen/quickshell.toml) writes it for each kind of GTK app:

- **libadwaita apps** (Nautilus and most GNOME apps) read it as `~/.config/gtk-4.0/gtk.css` (`[templates.gtk4]`), whatever GTK theme is set. They pick up new colors as they start.
- **GTK3 apps and plain GTK4 ones** (Blueman, nm-applet, pavucontrol, HandBrake...) get it through the **olShell** GTK theme, which matugen writes to `~/.local/share/themes/olShell/`: [adw-gtk3](https://github.com/lassekongo83/adw-gtk3)-dark (built on those names; adw-gtk3 while the Automatic theme's mode is Light) followed by these colors, for GTK3 (`gtk-3.0/`) and GTK4 (`gtk-4.0/`), from [gtk3-theme-index.css.template](matugen/gtk3-theme-index.css.template) and [gtk4-theme-index.css.template](matugen/gtk4-theme-index.css.template). Running apps never re-read a `gtk.css`, but they do reload their theme as its name changes, so a hook switches the name away and straight back after each run: open windows recolor at once.

To set it up:

- Install adw-gtk3 (`adw-gtk-theme` on Arch), run a theme or wallpaper change once so matugen writes the olShell theme, then select it: `gsettings set org.gnome.desktop.interface gtk-theme olShell`, and `gtk-theme-name=olShell` in `~/.config/gtk-3.0/settings.ini`. Restart already running GTK apps once.
- Don't keep a `~/.config/gtk-3.0/gtk.css`: an app reads it as it starts, above the theme, so it would pin that moment's colors.
- `~/.config/gtk-4.0/gtk.css` and `gtk-dark.css` must not be symlinks to a GTK theme (as `nwg-look`'s "export GTK4 symlinks" option or a theme installer leaves them): matugen would write through the link into the theme's own file, fail if it isn't yours, and stop the whole run there. Remove the links (and turn that option off); libadwaita prefers `gtk-dark.css` in dark mode, so a leftover one also hides the generated colors.
- Set the `org.gnome.desktop.interface color-scheme` to `prefer-dark` so the apps use the dark variant the palette is generated for (`gsettings set org.gnome.desktop.interface color-scheme prefer-dark`), or to `prefer-light` if you set the Automatic theme's mode to Light. The shell doesn't change it.
- Turn GTK off in the settings' **Theme** category (Other apps) if you don't want GTK apps themed.

## Qt

[matugen/qt-colors.conf.template](matugen/qt-colors.conf.template) is a Qt color scheme (a color for each palette role: window, base, button, highlight, tooltip, ... for active, inactive and disabled widgets) from the shell's palette, the same roles as [GTK](#gtk)'s. [matugen/quickshell.toml](matugen/quickshell.toml) writes it as the **olShell** color scheme of [qt6ct](https://github.com/trialuser02/qt6ct) (`~/.config/qt6ct/colors/olShell.conf`, for Qt6 apps) and of [qt5ct](https://sourceforge.net/projects/qt5ct/) (`~/.config/qt5ct/colors/olShell.conf`, for Qt5 apps). Running apps re-read their qt5ct / qt6ct settings a few seconds after that folder changes, so a hook touches `qt5ct.conf` / `qt6ct.conf` after each run: open windows recolor about three seconds later.

To set it up:

- Install qt6ct (and qt5ct for Qt5 apps), and have Qt apps use it: `env = QT_QPA_PLATFORMTHEME,qt6ct` in the Hyprland config (`qt5ct` instead for Qt5 apps, which only load their own). Log out and back in.
- Run a theme or wallpaper change once so matugen writes the olShell color scheme, then in qt6ct (and qt5ct) set the style to **Fusion** (it draws everything from the palette), check **Custom** under Palette, pick **olShell** and apply. Restart already running Qt apps once.
- KDE apps (Dolphin, Kate...) read KDE's own color schemes for part of their colors, so they are only partly themed.
- Turn Qt off in the settings' **Theme** category (Other apps) if you don't want Qt apps themed.

## Clock popup

Clicking the clock opens a popup (a click on the clock again, anywhere outside the popup, or **Escape** closes it; **Tab / Shift+Tab** switch tabs), placed like the other panels (the settings' **Panels** category, **Placement** tab, **Clock**: against the bar's middle by default, on the screen of the clock clicked), with a tab bar: **Agenda** (the default tab: a month calendar, weeks starting on Monday with ISO week numbers; the arrows browse months, "Aujourd'hui" jumps back, today is highlighted; no events yet) **Performances** (see the next section) and **Media**: a card for every app that speaks MPRIS, one under another in the order they appeared (scrolling past a few) (music and video players, browsers...), with the track's cover, title, artist and album, its progress with the elapsed and total times (click or drag the bar to seek, when the app allows it; a browser often doesn't give the track's length, e.g. Firefox and Zen for YouTube, and the bar then stays empty with dashes for the times; when it gives it at the start of a track and drops it part way through, as they do for some YouTube videos, the bar carries on from what it last gave, counting the time itself while the track plays, without seeking), shuffle, previous, play/pause, next and repeat (off, the playlist, the track; shuffle and repeat only when the app supports them), the app's own volume (when it has one; click its icon to mute the app, and again to give it back its volume), and a button bringing the app to the front; a browser is a single app, showing whichever of its tabs it treats as its active media. playerctld, which only stands in for the others, is left out. And **Weather**: the conditions now (icon, temperature, what it's like, the felt temperature, humidity and wind, with the place and the time it was fetched), the next 12 hours, and the next 7 days, each with its chance of rain and its low and high placed on a bar spanning the week's range, colored from the low's temperature to the high's (blue below 0 °C, then cyan, green, yellow and orange, red above 32 °C). It comes from [Open-Meteo](https://open-meteo.com) (free, no key), in the unit and for the place set in the settings (**Panels**, **Clock** tab), fetched every half hour while the tab is on and again when the unit or the place changes; if it fails, the tab says why and has a **Retry** button. `quickshell -p . ipc call weather now` prints it as JSON, `weather refresh` fetches it again. And **Clocks**: the local time, large, by an analog clock with a seconds hand and today's date, then a card for each place set in the settings (**Panels**, **Clock** tab), one to a row: an analog clock, the place, its time with a sun or a moon (day from 6 to 20 o'clock), and as pills whether it's today, tomorrow or yesterday there and how far ahead or behind it is, with its time zone's abbreviation; a card is tinted warm by day and deep blue by night; with no place yet, the local time shows alone, with a button opening those settings. The shell's JavaScript can't convert between time zones, so [scripts/timezones.py](scripts/timezones.py) gives each zone's offset (from the system's time zone data, daylight saving time included), asked again every ten minutes. From a script: `settings worldClocks` (prints them as JSON), `settings addWorldClock <name>`, `settings removeWorldClock <index>` and `settings moveWorldClock <index> <steps>`. The popup is as wide as its tab bar needs (520 px at least) and as tall as the tab being shown. To add a feature, append an entry to `tabs` and a page to the `StackLayout` in [ClockPanel.qml](modules/Clock/ClockPanel.qml).

## Performances

The **Performances** tab of the clock popup shows the machine's load at a glance, refreshed live:

- **Processeur** and **Mémoire**: a ring gauge with the current percentage (the CPU card adds frequency and core count, the memory card used / total), and a sparkline of the last samples.
- **Réseau**: instant download and upload speed with a sparkline of the last minute each. Only physical interfaces are counted (found through `/sys/class/net`), so a VPN or docker doesn't count the same traffic twice.
- **Stockage**: the main disk, the one mounted on `/`, with used / capacity and a usage bar. (`SystemStats.disks` lists every mounted disk, without pseudo file systems such as tmpfs and with a device mounted several times, e.g. btrfs subvolumes, listed once; the tab filters it to `/`.) Gauges and bars turn to `Theme.warningColor` above 90%.

The right part of the bar also has a disk widget (`DiskUsage`, after the RAM widget) showing how full the main disk, the one mounted on `/`, is, in percent (in the warning color above 90%); hovering it shows the used space over the capacity (e.g. "825.8 GiB used / 915.3 GiB"). It reads the same figures as the storage card above (`SystemStats.rootDisk`, refreshed every 20 s), and clicking it opens [gdu](#gdu) on that disk. It also has an instant download / upload speed widget (`NetworkSpeed`, between the disk and volume widgets), fed by the same network figures, refreshed every second. Its numbers have fixed widths so the bar does not shift as they change.

### Network connection

The network connection widget (`ConnectionButton`, after the network speed widget by default; a layout saved before it existed doesn't have it until you drag it into a lane in the settings' Bar widgets Layout tab, or `settings place connection right`) does what nm-applet's tray icon does, drawn like the rest of the bar. Its icon is the wired plug, or the Wi-Fi signal (four levels), while connected, in the warning color when the connection doesn't reach the internet; crossed out and dimmed while disconnected, and a network-off icon while networking is off. Hovering it says what it's connected to (the wired connection's name, or the Wi-Fi network and its signal) and the IPv4 address. A click (either button) opens a menu with, as in nm-applet: each wired device's connection (a click connects it) and **Disconnect**; the Wi-Fi networks in range, the strongest eight first, with their signal and a padlock for the secured ones (the connected one lit; a click connects: straight away to an open or known network, otherwise `nmcli --ask` asks for the password in a terminal) and **Disconnect**; **Connect to a hidden Wi-Fi network…** (its name and password asked in a terminal) and **Create a new Wi-Fi network…** (NetworkManager's connection editor); the VPN and WireGuard connections (a click switches one, the active ones lit) and **Add a VPN connection…**; **Enable networking** and **Enable Wi-Fi** check marks; **Connection information** (a popup with each active connection's interface, IPv4 and IPv6 addresses, gateway and DNS, until a click elsewhere); and **Edit connections…** (`nm-connection-editor`). The Wi-Fi scans while the menu is open. It reads Quickshell's Networking module, and NetworkManager through `nmcli` for what that module doesn't have ([services/NetworkManager.qml](services/NetworkManager.qml)), so it works without nm-applet running. The terminal it opens is `networkTerminal` in [config/Apps.qml](config/Apps.qml).

### Bluetooth

The Bluetooth widget (`BluetoothButton`, between the network connection and volume widgets by default; a layout saved before it existed doesn't have it until you drag it into a lane in the settings' Bar widgets Layout tab, or `settings place bluetooth right`) does what blueman's tray icon does, drawn like the rest of the bar. Its icon is crossed out and dimmed while Bluetooth is off or there is no adapter, and shows a link while a device is connected. Hovering it says whether Bluetooth is on and lists the connected devices, with their battery when they report it. A click opens blueman's device manager; a right click opens a menu to turn Bluetooth on or off, make the adapter discoverable (or stop), disconnect each connected device, send files to a device, reconnect one of the paired devices that aren't connected, and open blueman's **Devices**, **Adapters**, **Local services** and **Plugins** windows. It reads BlueZ through Quickshell's Bluetooth module, so it works without blueman running; the windows it opens are blueman's (the plugins one through `blueman-applet`, over D-Bus).

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
quickshell -p . ipc call chatai toggle                 # open/close the chat AI panel
quickshell -p . ipc call chatai ask "<question>"       # open it and ask (also: cancel, clear, answer, providers, select <id>, selectModel <id> <model>, selectDefault)
quickshell -p . ipc call switcher toggle               # open the app switcher, or move on while open (also: next, prev, confirm, close)
quickshell -p . ipc call settings toggle               # open/close the settings panel
quickshell -p . ipc call notifications toggle          # open/close the notification center
quickshell -p . ipc call clock toggle                  # open/close the clock panel (on the focused screen)
quickshell -p . ipc call weather now                   # the clock panel's weather as JSON (also: refresh)
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

The button is a bar widget like the others: it can be moved, turned off or given a divider from the settings panel's Bar widgets category. It is in the middle of the bar by default; a layout saved before it existed doesn't have it until you put it in a pill there (or `settings place screenshot center -1`). The clipboard copy and the notification are skipped if `wl-copy` or `notify-send` isn't installed.

## Notifications

olShell is a desktop notification server (the `org.freedesktop.Notifications` D-Bus service that `notify-send` and applications talk to), so it takes the place of mako, dunst or swaync: **only one of them can run**. Stop the other one and keep it from starting again (for swaync: `systemctl --user mask swaync`, since it is started by D-Bus on the first notification, and remove any autostart line for it), otherwise whichever starts first keeps the name and olShell logs "Could not register notification server".

- **Pop-ups** appear on the focused screen, at the top right by default (the *Notification position* setting puts them in another corner, at the middle of the top or bottom edge or halfway down the left or right one; at the top they are under the bar, and the newest is always the one nearest the edge):  the icon (the notification's image, else its application icon), summary, body (basic markup and links work) and one button per action. They stay for the *Pop-up duration* setting, or the time the sender asked for; urgent ones stay until closed; a line along the bottom shows the time left, and the timer stops while the pointer is over the pop-up. At most *Pop-ups at once* are shown, the others wait their turn. **Click** a pop-up to run its default action (if it has one) and put it away into the center; the cross closes it for good.
- **The center** is opened by the bell in the bar (or `ipc call notifications toggle`): every notification received, by application (newest first), in a panel placed like the other panels (the settings' **Panels** category, **Placement** tab, **Notification center**: against the bar's middle by default, on the focused screen), with the time, a cross per notification and per application, and **clear all**. Clicking a notification with a default action runs it and closes it. **Escape** or a click outside closes it; opening it puts any pop-ups away, since it shows them.
- **The bell** is a bar widget like the others, just before the power button by default (a layout saved before it existed doesn't have it until you drag it into a lane in the settings' Bar widgets Layout tab, or `settings place notifications right`). The bell is accent-colored while the center has notifications, and red while one of them is urgent. Their number is written to the right of the bell: it goes down only when one is dismissed, not when its pop-up goes away. A **right click** switches *do not disturb* on or off (also in the center's header and the settings' Notifications category): the bell is crossed out and no pop-up shows, except for urgent notifications; everything still goes to the center.
- The history is kept in memory: it is lost when the shell restarts. A notification an application replaces (`notify-send -r`) or closes is updated or removed here too.

[services/Notifications.qml](services/Notifications.qml) is the server and answers the IPC calls; [modules/Notifications/](modules/Notifications) has the pop-ups, the center and the notification card.

## Power

The power icon at the end of the bar (or `quickshell -p . ipc call power toggle`, to bind to a key) opens a panel attached to the bar under it, like the theme and wallpaper pickers (centered along the focused screen's bar when opened by the IPC call), with six actions on two rows of three: **Lock**, **Suspend** and **Log out** above, **Restart**, **UEFI setup** and **Shut down** below. **←/→** (or **Tab**) move between them, **↑/↓** switch rows, **Enter** or a click picks one, **Escape** or a click outside closes. Picking one closes the panel; lock and suspend happen at once, the others ask for confirmation (Enter or **Confirm** runs it, Escape or **Cancel** drops it). `ipc call power logout`, `restart` and `shutdown` skip the panel and go straight to that confirmation, so a script never powers the machine off unasked. Logging out is Hyprland's exit; the others are `systemctl reboot` and `systemctl poweroff`. The panel is [modules/Power/PowerPanel.qml](modules/Power/PowerPanel.qml), the confirmation [components/PowerConfirmDialog.qml](components/PowerConfirmDialog.qml) and the commands are in [config/PowerMenuState.qml](config/PowerMenuState.qml).

## Lock screen

The padlock icon just before the power icon (or `quickshell -p . ipc call lock lock`, to bind to a key) locks the screen. It is a Wayland session lock ([modules/Lock/LockScreen.qml](modules/Lock/LockScreen.qml)): the compositor shows only the lock surfaces, one per monitor, with the time, the date and a password field over the current wallpaper, blurred and slightly darkened (the theme background when there is none), until the password is right. Type it and press **Enter**; it is checked by PAM against your own login (the `login` stack, [services/Lock.qml](services/Lock.qml)), so it is the password you log in with. A wrong one says so and empties the field. The **Lock screen** category of the settings has **Lock after**: the minutes without keyboard or mouse input before the screen locks by itself, from 1 to 60, or **never** (0); the default is 8 (`lockTimeout` in `config/Settings.json`; `settings set lockTimeout 5`). Anything that inhibits idling (a video playing, for one) holds the timer off. So does a fullscreen focused window while **Stay awake in fullscreen** is on (the default; `lockStayAwakeFullscreen`): games, played with a gamepad, give no input the compositor counts and seldom inhibit idling themselves. The shell then inhibits idling itself, so an idle daemon such as hypridle doesn't blank the screen either. `ipc call lock status` prints 1 while the screen is locked, else 0. There is no unlock call, on purpose.

Reloading the shell (saving a file while developing it) while the screen is locked breaks the lock, and Hyprland then shows a lock-crashed message. To get out, switch to a text console (Ctrl+Alt+F3), log in, and run `hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'` then `hyprctl --instance 0 dispatch exec hyprlock` (Hyprland's hyprlock takes the lock over and unlocks with your password); or set `misc:allow_session_lock_restore = true` in your Hyprland config beforehand, so that starting the shell again is enough.

## Authentication (polkit)

The shell is the session's polkit authentication agent ([services/Polkit.qml](services/Polkit.qml), through Quickshell's Polkit module): when an application asks for administrator rights (`pkexec`, a package manager or a system settings window), a dialog ([modules/Polkit/PolkitDialog.qml](modules/Polkit/PolkitDialog.qml)) shows over the dimmed screen with the application's icon, what it wants to do, who authenticates (a choice when several administrators can) and a password field. **Enter** or **Authenticate** sends the password; a wrong one says so and empties the field for another try. **Escape**, **Cancel** or a click outside refuses the request. polkit accepts a single agent per session, so no other one (polkit-gnome, polkit-kde-agent...) may be started with Hyprland; while the shell isn't running, nothing can ask for the password and those requests fail.

## Lock keys OSD

Switching Caps Lock or Num Lock on or off briefly shows a popup at the bottom of the screen, where the volume OSD appears by default (the settings panel's **OSD** category places each of them), with the key's icon and its new state (accent-colored when on). The state isn't announced at startup, only on changes.

[services/LockKeys.qml](services/LockKeys.qml) runs [scripts/lock-keys-watch.py](scripts/lock-keys-watch.py), which polls the lock LEDs the kernel exposes in `/sys/class/leds/*::capslock` and `*::numlock` (ten times a second, from one process) and reports each change. A lock counts as on when any keyboard's LED is on, and keyboards plugged in later are picked up. This works on any compositor but needs those LEDs to exist, which is the case for ordinary keyboards.
