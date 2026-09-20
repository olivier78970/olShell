# olShell

olShell is a [Quickshell](https://quickshell.org) shell for Hyprland: a top bar replicated on every monitor, a btop window (click the CPU, RAM or network-speed widget to see just that part), a wiremix audio mixer window (click the volume widget), a bluetui Bluetooth window (left-click the Bluetooth tray icon), a gdu disk usage window (click the disk widget), an application launcher, a wallpaper picker and a theme picker (automatic from the wallpaper, or one of 10 fixed themes), a clock popup with an agenda and performance figures, live CPU / RAM / network-speed widgets, a volume OSD, a Caps Lock / Num Lock OSD and a power menu with confirmation, all in English or French.

## Requirements

- [Quickshell](https://quickshell.org) and Hyprland (workspaces and logout use the Hyprland integration)
- [matugen](https://github.com/InioX/matugen) and [awww](https://codeberg.org/LGFae/awww) for the wallpaper picker (awww is the wallpaper daemon; the shell starts it when it isn't running)
- [`wiremix`](https://github.com/tsowell/wiremix) for the audio mixer window (volume click)
- [`bluetui`](https://github.com/pythops/bluetui) for the Bluetooth window (left click on the Blueman tray icon)
- [`gdu`](https://github.com/dundee/gdu) for the disk usage window (click on the disk widget)
- PipeWire (volume)
- `btop` for the btop window, and a terminal (`alacritty` by default, configurable in [config/Apps.qml](config/Apps.qml)) for these windows
- the "0xProto Nerd Font" font, used for text and icons (see [config/Theme.qml](config/Theme.qml))
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
│   ├── Settings.qml          # Adjustable look-and-feel values, saved in Settings.json (Theme reads them)
│   ├── SettingsPanelState.qml   # Shared visibility of the settings panel
│   ├── I18n.qml, Translations.qml   # Localization: language choice + lookup, and the English / French texts
│   ├── ThemePanelState.qml   # Shared visibility of the theme panel
│   ├── LauncherState.qml     # Shared visibility of the launcher
│   ├── Paths.qml             # Wallpaper, matugen and palette locations
│   ├── Apps.qml              # Commands launched by clicking widgets
│   ├── PowerMenuState.qml    # Pending power action + the commands that run it
│   └── WallpaperPanelState.qml   # Shared visibility of the wallpaper panel
├── services/
│   ├── Audio.qml             # Default output volume/mute + `volume` IPC target
│   ├── LockKeys.qml          # Caps Lock / Num Lock state, from scripts/lock-keys-watch.py
│   ├── DesktopLocale.qml     # Application names/descriptions in the shell's language, read from the .desktop files
│   ├── TuiWindow.qml         # A TUI app in a floating, themed terminal window that opens/closes like a panel
│   ├── Btop.qml              # The btop window (toggle + `btop` IPC target)
│   ├── Wiremix.qml           # The wiremix window (toggle + `wiremix` IPC target)
│   ├── Bluetui.qml           # The bluetui window (toggle + `bluetui` IPC target)
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
│   └── SettingSlider.qml, ChoiceRow.qml   # Rows of the settings panel
├── modules/                  # One directory per feature (import qs.modules.<Name>)
│   ├── Bar/                  # The top bar
│   │   ├── Bar.qml           # Top bar, one per screen
│   │   └── Widgets/          # What sits in the bar (import qs.modules.Bar.Widgets)
│   │       ├── Workspaces, ActiveWindow, Clock, WallpaperTrigger, ThemeTrigger, LauncherTrigger, LanguageTrigger, SettingsTrigger
│   │       ├── ClockPanel.qml, AgendaTab.qml, PerformanceTab.qml   # Clock popup: tab bar + pages
│   │       ├── Tray, TrayItem, TrayMenuItem
│   │       ├── CpuUsage, RamUsage, DiskUsage, NetworkSpeed, Volume
│   │       └── PowerMenu
│   ├── Launcher/LauncherPanel.qml     # Application launcher (ModalPanel + desktop entries)
│   ├── Osd/                  # Bottom-of-screen popups
│   │   ├── VolumeOsd.qml     # Volume
│   │   └── LockKeysOsd.qml   # Caps Lock / Num Lock
│   ├── Settings/SettingsPanel.qml     # Settings panel (built from SettingSlider and ChoiceRow)
│   ├── Theme/ThemePanel.qml           # Theme picker (CarouselPanel + ThemeState)
│   └── Wallpapers/WallpaperPanel.qml  # Wallpaper picker (CarouselPanel + awww/matugen)
├── scripts/apply-wallpaper.py   # Shows an image as the wallpaper with awww, starting its daemon if needed (used by the wallpaper panel)
├── scripts/lock-keys-watch.py   # Prints the Caps/Num Lock state on every change (used by services/LockKeys.qml)
├── scripts/tui-launch.py     # Themes and starts btop, wiremix, bluetui or gdu in a terminal (used by services/TuiWindow.qml)
└── matugen/                  # Everything matugen: its config and every template it fills
    ├── quickshell.toml       # The config: the shell's palette and the other apps' colors (Hyprland, Zen, alacritty, starship)
    ├── quickshell-theme.json.template   # Template of the shell's palette (written to config/GeneratedColors.json)
    ├── hyprland-theme.lua.template      # Template of Hyprland's colors (~/.config/hypr/colors.lua)
    ├── zen-theme.css.template           # Template coloring Zen browser
    ├── alacritty-theme.toml.template    # Template coloring alacritty
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

| Setting | Range | Default |
|---|---|---|
| Widget radius | 0 – 30 px | 5 |
| Language | Automatic / English / Français | Automatic |
| Widget opacity | 40 – 100 % | 90 % |
| Widget spacing | 0 – 40 px | 15 |
| Top bar height | 28 – 72 px | 40 |
| Top bar top margin | 0 – 100 px | 5 |
| Top bar left margin | 0 – 300 px | 5 |
| Top bar right margin | 0 – 300 px | 5 |
| Border width | 0 – 6 px | 2 |

Click or drag a slider, or use the keys: **↑/↓** select a row, **←/→** adjust it (**Shift** for bigger steps), **Escape** closes. **Reset** puts everything back to the defaults, language included. Note that the bar height also scales the text (as before), so a very tall bar with big margins can make the bar's three groups collide.

From a script: `quickshell -p . ipc call settings set <key> <value>` (keys: `radius`, `opacity`, `spacing`, `barHeight`, `barMarginTop`, `barMarginLeft`, `barMarginRight`, `borderWidth`; out-of-range values are clamped), `settings get <key>` and `settings reset`.

Values live in [config/Settings.qml](config/Settings.qml), which `Theme` reads, so to make another value adjustable add it there (default, limits, property), point `Theme` at it, and add a row in [modules/Settings/SettingsPanel.qml](modules/Settings/SettingsPanel.qml) and its label in [config/Translations.qml](config/Translations.qml).

## Localization

The shell speaks **English** and **French**. By default it follows the system language (`LC_ALL`, `LC_MESSAGES` or `LANG`; English if that isn't one of the two). The **EN / FR** button at the right end of the middle pill switches to the other language, and the choice is remembered in `config/LocaleState.json` (git-ignored). It can also be set from a key binding or a script:

```sh
quickshell -p . ipc call language set fr      # or en, or auto to follow the system again
quickshell -p . ipc call language toggle
quickshell -p . ipc call language get
```

Everything is switched at once: texts, dates and month/day names, decimal separators, and units (Gio / GiB). The week still starts on Monday in both.

The launcher's application names, descriptions and keywords follow the shell's language too, not the system's: every `.desktop` file carries all its translations (`Comment[fr]=...`), so [services/DesktopLocale.qml](services/DesktopLocale.qml) reads them straight from the files (the user's and system's `applications` directories, in priority order) and picks the best one for the current language (`language_COUNTRY`, then `language`, then the untranslated text), instead of the single language Quickshell reads at startup. Searching matches the translated name and keywords as well as the untranslated name ("files" still finds Fichiers). The files are read again each time the launcher opens; an application with no readable file falls back to Quickshell's own text.

The texts are in [config/Translations.qml](config/Translations.qml), one dictionary per language with dotted keys (`power.logout`); [config/I18n.qml](config/I18n.qml) looks them up with `I18n.tr("key", args...)`, replacing `{0}`, `{1}`... and choosing between `one` / `other` forms for counts. A key missing from a language falls back to English, then shows the key itself. To add a language: add a dictionary with the same keys as `en` (including `format.locale`, `format.decimal`, `format.units`, `format.dateTime`) and list its code in `I18n.supported`. Use `I18n.tr` for any new visible text rather than a literal.

## btop

Clicking the CPU, RAM or network-speed widget opens btop in a terminal window showing only that widget's box (its **cpu**, **mem** or **net** box), and clicking again closes it. The same from a key binding: `quickshell -p . ipc call btop cpu` (or `memory`, `network`); `quickshell -p . ipc call btop toggle` opens the full btop, with the boxes of your own configuration, which no widget does. A single-box window is smaller (50% × 50% of the monitor; `btopBoxWidth` and `btopBoxHeight` in [config/Apps.qml](config/Apps.qml)); the full one is 85% × 90%. The box is chosen by setting `shown_boxes` in the copy of your `btop.conf` described below (for the memory box, `show_disks` is turned off too, since btop would draw the disks inside it; see `boxSettings` in [services/Btop.qml](services/Btop.qml)), so your own configuration and its layout are not touched. There is one btop window, so a click on another widget while it is open closes it instead of switching to that widget's box. [services/TuiWindow.qml](services/TuiWindow.qml) (shared with wiremix, below) launches the terminal through Hyprland with launch-time window rules (floating, centered, sized to a fraction of the focused monitor), so nothing needs adding to your Hyprland config. The window has its own class (`quickshell-btop`), which is how the toggle finds it to close it, even after a shell reload.

The window is themed with the shell's current colors: [scripts/tui-launch.py](scripts/tui-launch.py) generates a btop theme from the palette (background, text, accent, outline) each time it opens, plus a copy of your `btop.conf` that selects it, in `$XDG_RUNTIME_DIR/quickshell-btop/`, and starts the terminal with matching colors (for alacritty). Your own `~/.config/btop/btop.conf` is never modified; settings you change inside this btop are saved to the copy, and it picks up the theme that's active when it's opened.

It is a real terminal window, so btop works completely (mouse, copy/paste, resizing) but it's an ordinary window: no dimmed backdrop, and clicking elsewhere or pressing Escape doesn't close it. The terminal and size (as fractions of the monitor, 85% × 90% by default) are in [config/Apps.qml](config/Apps.qml) (`btopTerminal`, `btopWidth`, `btopHeight`); another terminal works too, but only alacritty gets the colors applied (btop itself is themed either way).

## wiremix

Clicking the volume widget (or `quickshell -p . ipc call wiremix toggle`) opens [wiremix](https://github.com/tsowell/wiremix), a TUI mixer for PipeWire, in a terminal window, and clicking again (or the same call) closes it. It works exactly like the btop window above: the same [services/TuiWindow.qml](services/TuiWindow.qml) opens it floating and centered (60% × 70% of the monitor by default) with its own window class (`quickshell-wiremix`), and [scripts/tui-launch.py](scripts/tui-launch.py) themes it with the shell's colors. It has tabs for playback, recording, output and input devices and the device configuration; press **?** inside for its keys.

The theme is a `[themes.quickshell]` table appended to a copy of your `~/.config/wiremix/wiremix.toml` (if you have one) in `$XDG_RUNTIME_DIR/quickshell-wiremix/`, selected on the command line, so your own configuration is never modified and its `theme` option is overridden only for this window. The terminal and size are in [config/Apps.qml](config/Apps.qml) (`wiremixTerminal`, `wiremixWidth`, `wiremixHeight`). Scrolling over the volume widget still adjusts the volume.

Both this window and the btop one are as translucent as the widgets (the **Widget opacity** setting, read each time a window opens), so Hyprland blurs what's behind them if its blur is enabled. To make that possible the applications don't paint a background of their own (btop's `theme_background` is turned off in the copy of its config) and the terminal window's opacity is set to the widget opacity, overriding your terminal's own setting (only alacritty is handled, as for the colors).

## bluetui

Left-clicking the Bluetooth icon in the tray (or `quickshell -p . ipc call bluetui toggle`) opens [bluetui](https://github.com/pythops/bluetui), a TUI Bluetooth manager, in a terminal window (50% × 60% of the monitor by default), and clicking again (or the same call) closes it. It is the same machinery as the btop and wiremix windows: [services/TuiWindow.qml](services/TuiWindow.qml) opens it floating and centered with its own window class (`quickshell-bluetui`), and the window is as translucent as the widgets. bluetui has no theme option, so it takes the colors of the terminal, which [scripts/tui-launch.py](scripts/tui-launch.py) sets from the shell's palette (alacritty only).

Which tray icons behave this way is [config/Apps.qml](config/Apps.qml)'s `trayLeftClick`, a table from a tray item's id (the application's name: `blueman` for Blueman's icon) to what the left click does instead of the application's own action; only `"bluetui"` exists for now. Right and middle clicks are unchanged, so Blueman's own menu is still on the right click. The terminal and size are `bluetuiTerminal`, `bluetuiWidth` and `bluetuiHeight`.

## gdu

Clicking the disk widget (or `quickshell -p . ipc call gdu toggle`) opens [gdu](https://github.com/dundee/gdu), an interactive disk usage analyzer, on the disk mounted on `/`, and clicking again (or the same call) closes it. It shows which folders take the room, largest first: **Enter** goes into a folder, **←** back out, **d** deletes the selected item (with confirmation), **?** lists the other keys. (btop can't be used for this: it draws the disks inside its memory box, and nothing hides the memory part.) The window works like the others: [services/TuiWindow.qml](services/TuiWindow.qml) opens it floating and centered (60% × 70% of the monitor by default) with its own window class (`quickshell-gdu`), as translucent as the widgets.

gdu is started with `--no-cross`, so it stays on the filesystem of `/` (other disks and mounts such as `/boot/efi` aren't counted, as the widget doesn't count them; note that on btrfs, subvolumes such as `/home` count as other filesystems, so remove `--no-cross` in [scripts/tui-launch.py](scripts/tui-launch.py) there). It reads its styles from a file the launcher writes, `$XDG_RUNTIME_DIR/quickshell-gdu/gdu.yaml`, with the shell's colors for the header, footer, selected row and directories; that replaces gdu's default `~/.gdu.yaml` for this window only, so a configuration of yours is not used here (and never modified). The terminal and size are in [config/Apps.qml](config/Apps.qml) (`gduTerminal`, `gduWidth`, `gduHeight`).

## Launcher

The apps icon in the middle of the bar, or `quickshell -p . ipc call launcher toggle` (bind it to a key), opens a search box over the installed applications (their `.desktop` entries). Type to filter: matches names first (exact, prefix, word prefix, anywhere), then generic name, keywords, category and description, and finally letters in order (`ffx` finds Firefox). **↑/↓**, **Tab / Shift+Tab**, **Ctrl+N / Ctrl+P** (or **Ctrl+J / Ctrl+K**) and **Page Up / Down** move the selection, **Enter** launches it, **Escape** or a click outside closes. Hovering moves the selection too and a click launches; resting the pointer on an entry for half a second shows a tooltip with the real process name (e.g. "Fichiers" → `nautilus`), its full command and its desktop-entry id. With an empty search the list is alphabetical.

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

Alacritty reloads imported files while it runs, so open terminals recolor as soon as the wallpaper or theme changes, with no restart (unlike [Zen](#zen-browser)). Remove the `[templates.alacritty]` block from `quickshell.toml` if you don't use alacritty. The same goes for the `[templates.hyprland]` (writes `~/.config/hypr/colors.lua`) and `[templates.starship]` (writes `~/.config/starship/starship.toml`, **replacing** that file: keep your prompt's layout in the template) blocks. The btop, wiremix, bluetui and gdu windows the shell opens set their own colors from the shell's theme and don't use this file.

## Clock popup

Hovering the clock opens a popup (it stays open while the pointer is over it) with a tab bar: **Agenda** (the default tab: a month calendar, weeks starting on Monday with ISO week numbers; the arrows browse months, "Aujourd'hui" jumps back, today is highlighted; no events yet) and **Performances** (see the next section). The popup is as wide as its tab bar needs (520 px at least) and as tall as the tab being shown. To add a feature, append an entry to `tabs` and a page to the `StackLayout` in [ClockPanel.qml](modules/Bar/Widgets/ClockPanel.qml).

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

Applying goes through [scripts/apply-wallpaper.py](scripts/apply-wallpaper.py), which runs `awww img`. awww draws nothing unless its daemon (`awww-daemon`) is running, so the script starts it, detached from the shell, when it isn't, which means nothing has to start it at login: the shell applies the last wallpaper (the one remembered in `config/ThemeState.json`) as soon as it starts and again 5 seconds later (in case a new picture of the day was downloaded meanwhile), so the wallpaper is back at login (the `applyLast` IPC call does the same on demand, see [IPC](#ipc)); the shell no longer uses waypaper, so waypaper's own config is not updated and `waypaper --restore` would restore an older image. The image fill and the transition (a 2 s fade) are the `wallpaperOptions` of [config/Apps.qml](config/Apps.qml), any `awww img` options.

## IPC

Bind these to keys, e.g. from Hyprland:

```sh
quickshell -p . ipc call wallpapers wallpapersToggle   # open/close the wallpaper panel
quickshell -p . ipc call wallpapers applyPod           # apply the Bing picture of the day
quickshell -p . ipc call wallpapers applyRandom        # apply a random wallpaper other than the current one
quickshell -p . ipc call wallpapers applyLast          # apply the last applied wallpaper again (e.g. after a new picture of the day was downloaded)
quickshell -p . ipc call btop toggle                   # open/close the full btop window
quickshell -p . ipc call btop cpu                      # ... showing only the CPU box (also: memory, network)
quickshell -p . ipc call wiremix toggle                # open/close the wiremix window
quickshell -p . ipc call bluetui toggle                # open/close the bluetui window
quickshell -p . ipc call gdu toggle                    # open/close the gdu window
quickshell -p . ipc call launcher toggle               # open/close the application launcher
quickshell -p . ipc call settings toggle               # open/close the settings panel
quickshell -p . ipc call themes themesToggle       # open/close the theme panel
quickshell -p . ipc call volume increase 0.05
quickshell -p . ipc call volume decrease 0.05
quickshell -p . ipc call volume mute
```

Volume changes from any source (these calls, media keys, wiremix, pavucontrol...) also show the OSD.

## Lock keys OSD

Switching Caps Lock or Num Lock on or off briefly shows a popup at the bottom of the screen, next to where the volume OSD appears, with the key's icon and its new state (accent-colored when on). The state isn't announced at startup, only on changes.

[services/LockKeys.qml](services/LockKeys.qml) runs [scripts/lock-keys-watch.py](scripts/lock-keys-watch.py), which polls the lock LEDs the kernel exposes in `/sys/class/leds/*::capslock` and `*::numlock` (ten times a second, from one process) and reports each change. A lock counts as on when any keyboard's LED is on, and keyboards plugged in later are picked up. This works on any compositor but needs those LEDs to exist, which is the case for ordinary keyboards.
