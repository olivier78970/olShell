## btop

Clicking the CPU, RAM or network-speed widget opens btop in a terminal window showing only that widget's box (its **cpu**, **mem** or **net** box), and clicking again closes it.
The same from a key binding: `quickshell -p . ipc call btop cpu` (or `memory`, `network`); `quickshell -p . ipc call btop toggle` opens the full btop, with the boxes of your own configuration, which no widget does.
A single-box window is smaller (50% × 50% of the monitor; `btopBoxWidth` and `btopBoxHeight` in [config/Apps.qml](../config/Apps.qml)); the full one is 85% × 90%.
The box is chosen by setting `shown_boxes` in the copy of your `btop.conf` described below (for the memory box, `show_disks` is turned off too, since btop would draw the disks inside it; see `boxSettings` in [services/Btop.qml](../services/Btop.qml)), so your own configuration and its layout are not touched.
There is one btop window, so a click on another widget while it is open closes it instead of switching to that widget's box.
[services/TuiWindow.qml](../services/TuiWindow.qml) (shared with the gdu window, below) launches the terminal through Hyprland with launch-time window rules (floating, centered, sized to a fraction of the focused monitor), so nothing needs adding to your Hyprland config.
The window has its own class (`quickshell-btop`), which is how the toggle finds it to close it, even after a shell reload.

The window is themed with the shell's current colors: [scripts/tui-launch.py](../scripts/tui-launch.py) generates a btop theme from the palette (background, text, accent, outline) each time it opens, plus a copy of your `btop.conf` that selects it, in `$XDG_RUNTIME_DIR/quickshell-btop/`, and starts the terminal with matching colors (for alacritty).
Your own `~/.config/btop/btop.conf` is never modified; settings you change inside this btop are saved to the copy, and it picks up the theme that's active when it's opened.

It is a real terminal window, so btop works completely (mouse, copy/paste, resizing) but it's an ordinary window: no dimmed backdrop, and clicking elsewhere or pressing Escape doesn't close it.
The terminal and size (as fractions of the monitor, 85% × 90% by default) are in [config/Apps.qml](../config/Apps.qml) (`btopTerminal`, `btopWidth`, `btopHeight`); another terminal works too, but only alacritty gets the colors applied (btop itself is themed either way).

## Audio mixer

Clicking the volume widget opens [pavucontrol](https://freedesktop.org/software/pulseaudio/pavucontrol/), and clicking again closes it (whichever way it was opened); a middle click mutes or unmutes the output (the OSD shows it).
It's an ordinary window of its own, in the shell's colors through the olShell GTK theme (see [GTK](theming.md#gtk)).
Scrolling over the volume widget adjusts the volume.

The btop window is as translucent as the widgets (the **Widget opacity** setting, read each time a window opens), so Hyprland blurs what's behind them if its blur is enabled.
To make that possible the applications don't paint a background of their own (btop's `theme_background` is turned off in the copy of its config) and the terminal window's opacity is set to the widget opacity, overriding your terminal's own setting (only alacritty is handled, as for the colors).

## gdu

Clicking the disk widget (or `quickshell -p . ipc call gdu toggle`) opens [gdu](https://github.com/dundee/gdu), an interactive disk usage analyzer, on the disk mounted on `/`, and clicking again (or the same call) closes it.
It shows which folders take the room, largest first: **Enter** goes into a folder, **←** back out, **d** deletes the selected item (with confirmation), **?** lists the other keys.
(btop can't be used for this: it draws the disks inside its memory box, and nothing hides the memory part.)
The window works like the others: [services/TuiWindow.qml](../services/TuiWindow.qml) opens it floating and centered (60% × 70% of the monitor by default) with its own window class (`quickshell-gdu`), as translucent as the widgets.

gdu is started with `--no-cross`, so it stays on the filesystem of `/` (other disks and mounts such as `/boot/efi` aren't counted, as the widget doesn't count them; note that on btrfs, subvolumes such as `/home` count as other filesystems, so remove `--no-cross` in [scripts/tui-launch.py](../scripts/tui-launch.py) there).
It reads its styles from a file the launcher writes, `$XDG_RUNTIME_DIR/quickshell-gdu/gdu.yaml`, with the shell's colors for the header, footer, selected row and directories; that replaces gdu's default `~/.gdu.yaml` for this window only, so a configuration of yours is not used here (and never modified).
The terminal and size are in [config/Apps.qml](../config/Apps.qml) (`gduTerminal`, `gduWidth`, `gduHeight`).

## Launcher

The apps icon in the middle of the bar, or `quickshell -p . ipc call launcher toggle` (bind it to a key), opens a search box over the installed applications (their `.desktop` entries;
one that runs in a terminal, such as yazi or htop, opens in `appTerminal` from [config/Apps.qml](../config/Apps.qml), alacritty by default, in a floating window centered on the focused monitor, sized by `appTerminalWidth` and `appTerminalHeight` there).
Type to filter: matches names first (exact, prefix, word prefix, anywhere), then generic name, keywords, category and description, and finally letters in order (`ffx` finds Firefox).
The tabs show their icon only, their name in a tooltip on hover.
**Tab / Shift+Tab** switch tabs (keeping what you typed; so do **Alt+1…6** and a click); **↑/↓**, **Ctrl+N / Ctrl+P** (or **Ctrl+J / Ctrl+K**) and **Page Up / Down** move the selection, **Enter** launches it, **Escape** or a click outside closes.
Hovering moves the selection too and a click launches; resting the pointer on an entry for half a second shows a tooltip with the real process name (e.g.
"Fichiers" → `nautilus`), its full command and its desktop-entry id.
With an empty search the list is alphabetical, after the applications (and games) last opened from the launcher, the latest first and selected, so **Enter** opens it again;
how many is the **History length** setting of the **Launcher** category (`launcherHistory`, 0 to 10, 3 by default;
0 turns it off), and the history is remembered across restarts (`config/LauncherState.json`).
The **All** tab groups what it finds under headings: the best applications, then the best games (the Games tab's, left out of its applications), web apps, files and the web; with an empty search, the ones last opened under **Recently opened**, then every other application, then every other game.
The web tab opens what you typed if it looks like an address, then offers a search with each web search engine set in the settings' **Launcher** category, in their order: by default the default browser's own default engine, then YouTube and Wikipedia; the web section of the All tab has the same.
The **Web apps** tab lists the web apps switched on in the settings' **Web apps** category (see [Web apps](#web-apps)), in their order, with their site's icon; typing filters them by name, then address.
Enter opens one, or switches to its window when it is already open.
There each engine has a row with a check box (offered or not), its name and its address (click one, or press **Enter** on it, to type in it;
**Enter** saves, **Escape** cancels;
an address must start with `http://` or `https://` and have `%s` where the search goes, or the field stays open), ‹ › arrows to move it and a bin to remove it;
on the keys, **←/→** move between these and **Shift+←/→** move the engine.
**Add** (the row under them) adds one and starts typing its name.
The browser's engine can be turned off and moved but not removed; its row names the engine found.
The list is `launcherEngines` in `config/Settings.json`, and from a script: `settings engines` (prints it as JSON), `settings addEngine <name> <url>`, `settings removeEngine <index>`, `settings moveEngine <index> <steps>` and `settings engineOn <index> <1|0>` (index from 0, in the list's order).
The apps added to the themed apps (settings' **Theme** category) go the same way: `settings matugenApps` (prints them as JSON), `settings addMatugenApp <name> <template> <output> <command>` (`""` for no command), `settings removeMatugenApp <index>` and `settings matugenAppOn <index> <1|0>`.
The apps with an opacity of their own (Appearance's **App opacity** tab) too: `settings appOpacities` (prints them as JSON), `settings setAppOpacity <class> <focused> <not focused>` (Hyprland's window class, opacities from 0.1 to 1;
adds the app if it has none yet) and `settings linkAppOpacity <class> <focused 1|0> <not focused 1|0>` (follow the general window opacity, or not) and `settings removeAppOpacity <class>`.
The browser's default engine is read from the browser's profile each time the launcher opens by [scripts/default-search-engine.py](../scripts/default-search-engine.py), for Firefox and the browsers built on it (Zen, LibreWolf, Floorp, Waterfox) and for the Chromium-based ones.
When it can't be read (another browser, or a built-in engine the script doesn't know), DuckDuckGo is used in its place (`webSearchFallback` in [config/Apps.qml](../config/Apps.qml)).
The **Games** tab lists only the applications in the Game category (`Categories=Game;` in their desktop entry): the games' shortcuts made by Faugus, Heroic or Steam, and other games installed as applications; a game without a desktop entry doesn't show.
The launchers and tools that put themselves in that category too (Steam, Heroic, Faugus, GOverlay) are left out: `notGames` in [config/Apps.qml](../config/Apps.qml), by desktop entry id (the file name without `.desktop`), lists them.
The settings panel's **Launcher** category sets the tab it opens on (`launcherTab`) how many results it shows at once at most (`launcherResults`, 3 to 20; the rest scroll) and how many recently opened applications it lists first (`launcherHistory`).
The launcher is as tall as the results it shows, up to that many, and its top stays put as it grows and shrinks.

## App switcher

`quickshell -p . ipc call switcher toggle` opens a panel listing Hyprland's open windows, the most recently focused first, each with its icon, title, app and workspace, and the previously focused one selected.
**↑/↓**, **Tab / Shift+Tab** (or **←/→**) move the selection, **Enter** or a click switches to the window (on its workspace), **Escape** or a click outside closes.
It is placed like the other panels (the settings' **Panels** category, `switcherPlacement`), and lists the windows in a column of rows or side by side as cards, each a large icon (or a live picture of the window) with the title and, a line each, the app and workspace under it (on a card the title wraps onto two lines before it's cut).
The **App switcher** tab of that category sets its direction, which windows it lists (all, the focused workspace's or the focused screen's), whether it gathers them by app (the key above Tab, ² on a French keyboard, then goes through the selected app's windows), what it shows with each window (title, app, workspace), its icon size, how many windows show at once before it scrolls, whether releasing the shortcut switches, and the pictures (see the table above).

Bound to a shortcut in the Hyprland config, e.g. `hl.bind("SUPER + TAB", hl.dsp.exec_cmd("qs ipc call switcher toggle"))`, it works like Alt+Tab with that shortcut, whatever it is: it finds the shortcut in the config each time it opens (with [scripts/list-shortcuts.py](../scripts/list-shortcuts.py)), then pressing it again while holding its modifier moves on (with **Shift** added, back), and releasing the modifier switches to the selected window.
So `toggle` only closes it when its shortcut has no modifier; otherwise **Escape** does, or `switcher close`.

`switcher next` and `switcher prev` step the same way (the first opens it on the previously focused window, the second on the last one), for binds of your own; releasing Super, Alt or Ctrl switches then, or the `toggle` shortcut's modifiers once it is known.
The panel only sees that release once it has the keyboard, so a very quick press can be over before it does: bind `switcher confirm`, which switches to the selected window, to the modifier's release in Hyprland too.

## Keyboard shortcuts

`quickshell -p . ipc call shortcuts toggle` (bind it to a key) opens a panel centered on the screen listing the shortcuts of the Hyprland config that use the **Super** key, keyboard and mouse (media keys, Print Screen and other keys without Super are left out), grouped (applications, shell, windows, workspaces) and described in the shell's language: "Go to workspace 1", "Open the launcher" for a shell IPC call, "Open zen-browser" with its full command under it.
Type to filter (keys, description or command); **↑/↓** and **Page Up / Down** scroll, **Escape** or a click outside closes.
A bind's own `description` option, if it has one, is shown instead.

A Lua config binds each shortcut to a Lua function, so Hyprland itself (`hyprctl binds`) only knows its keys: [scripts/list-shortcuts.py](../scripts/list-shortcuts.py) reads what they do from the config's `hl.bind(...)` calls instead, each time the panel opens, following its `require(...)`s and resolving its string variables (`terminal`, `mainMod`...).
Binds it can't read (built in a loop, say) are counted against Hyprland's own list of Super binds, and the panel says how many are missing.

## Web apps

The web apps widget (a globe, first on the left of the bar) opens a menu of web apps, each with its site's icon: sites that each open in a window of their own.
They are opened with the **Command** at the top of the **Web apps** settings, `%s` in it standing for the address (added at the end without one): by default `zen-browser -P webapp --new-window %s`, Zen browser's `webapp` profile, kept apart from the everyday profile with its own logins and add-ons (`chromium --app=%s` would open them as Chromium app windows instead).
The command is split into words as a shell would (quotes group words) but run without one.
In the menu, a dot after a web app's name means its window is open.
Clicking a web app whose window is still open switches to that window (on its workspace) instead of opening it again: the first window that opens in the 15 seconds after a web app is launched is taken as its own, until it is closed.
Windows opened before the shell last started aren't known, so the next click opens a new one.
The launcher's **Web apps** tab lists them too.
They are managed in the **Web apps** category of the settings, where they are added, named, given their address, ordered, switched off (left out of the menu) and removed.
The icon is the site's favicon (the largest one its page names, else its `/favicon.ico`), found by [scripts/favicon.py](../scripts/favicon.py) when a web app is added or its address changes, and kept per site in `~/.cache/olShell/favicons` (delete a file there to have it looked for again at the next start;
a site with none is looked for again at each start).
With the default command, the profile has to exist: create it once with `zen-browser -P` (the profile manager) and name it `webapp`.
Over IPC, `quickshell -p . ipc call webApps open <name>` opens one by name (bind it to a key) and `webApps list` prints them as JSON, with whether each one's window is open.

## Clock popup

Clicking the clock opens a popup (a click on the clock again, anywhere outside the popup, or **Escape** closes it;
**Tab / Shift+Tab** switch tabs), placed like the other panels (the settings' **Panels** category, **Placement** tab, **Clock**: against the bar's middle by default, on the screen of the clock clicked), with a tab bar: **Agenda** (the default tab: a month calendar, weeks starting on Monday with ISO week numbers;
the arrows browse months, "Aujourd'hui" jumps back, today is highlighted;
no events yet) **Performances** (see the next section) and **Media**: a card for every app that speaks MPRIS, one under another in the order they appeared (scrolling past a few) (music and video players, browsers...), with the track's cover, title, artist and album, its progress with the elapsed and total times (click or drag the bar to seek, when the app allows it;
a browser often doesn't give the track's length, e.g. Firefox and Zen for YouTube, and the bar then stays empty with dashes for the times;
when it gives it at the start of a track and drops it part way through, as they do for some YouTube videos, the bar carries on from what it last gave, counting the time itself while the track plays, without seeking), shuffle, previous, play/pause, next and repeat (off, the playlist, the track;
shuffle and repeat only when the app supports them), the app's own volume (when it has one;
click its icon to mute the app, and again to give it back its volume), and a button bringing the app to the front;
a browser is a single app, showing whichever of its tabs it treats as its active media. playerctld, which only stands in for the others, is left out.
And **Weather**: the conditions now (icon, temperature, what it's like, the felt temperature, humidity and wind, with the place and the time it was fetched), the next 12 hours, and the next 7 days, each with its chance of rain and its low and high placed on a bar spanning the week's range, colored from the low's temperature to the high's (blue below 0 °C, then cyan, green, yellow and orange, red above 32 °C).
It comes from [Open-Meteo](https://open-meteo.com) (free, no key), in the unit and for the place set in the settings (**Panels**, **Clock** tab), fetched every half hour while the tab is on and again when the unit or the place changes; if it fails, the tab says why and has a **Retry** button.
`quickshell -p . ipc call weather now` prints it as JSON, `weather refresh` fetches it again.
And **Clocks**: the local time, large, by an analog clock with a seconds hand and today's date, then a card for each place set in the settings (**Panels**, **Clock** tab), one to a row: an analog clock, the place, its time with a sun or a moon (day from 6 to 20 o'clock), and as pills whether it's today, tomorrow or yesterday there and how far ahead or behind it is, with its time zone's abbreviation;
a card is tinted warm by day and deep blue by night;
with no place yet, the local time shows alone, with a button opening those settings.
The shell's JavaScript can't convert between time zones, so [scripts/timezones.py](../scripts/timezones.py) gives each zone's offset (from the system's time zone data, daylight saving time included), asked again every ten minutes.
From a script: `settings worldClocks` (prints them as JSON), `settings addWorldClock <name>`, `settings removeWorldClock <index>` and `settings moveWorldClock <index> <steps>`.
The popup is as wide as its tab bar needs (520 px at least) and as tall as the tab being shown.
To add a feature, append an entry to `tabs` and a page to the `StackLayout` in [ClockPanel.qml](../modules/Clock/ClockPanel.qml).

## Wallpapers

The picker lists images from `~/.config/wallpapers/bing/saved/`, plus `~/.config/wallpapers/bing/pod.jpg` (the Bing picture of the day) as the first entry.
Both locations, and the config directory root (`$XDG_CONFIG_HOME`), are set in [config/Paths.qml](../config/Paths.qml).

The pictures are shown in a carousel: by default the selected one large and in front, three on each side stacked behind it, overlapping, turned slightly toward it, smaller and darker the further they are, sliding into place as you browse.
The **Wallpaper** category of the settings changes its style (a cover flow, a gentle tilt, a flat fan, a fanned deck of cards, or side by side) and how many wallpapers show on each side.
Left/Right or the mouse wheel browse without changing anything; **Enter**, clicking a picture, "Image du jour" or "Aléatoire" (top right, next to it: a random wallpaper other than the one in use) applies it (awww sets it, matugen regenerates the palette).
**Escape** or a click outside closes the panel.

Applying goes through [scripts/apply-wallpaper.py](../scripts/apply-wallpaper.py), which runs `awww img`. awww draws nothing unless its daemon (`awww-daemon`) is running, so the script starts it, detached from the shell, when it isn't, which means nothing has to start it at login: the shell applies the last wallpaper (the one remembered in `config/ThemeState.json`) as soon as it starts, and again 5 seconds later if it is the picture of the day (in case a new one was downloaded meanwhile), so the wallpaper is back at login (the `applyLast` IPC call does the same on demand, see [IPC](ipc.md#ipc));
the shell no longer uses waypaper, so waypaper's own config is not updated and `waypaper --restore` would restore an older image.
The transition's type and duration (a 2 s fade by default) are [settings](settings.md#settings); the image fill and the transition's smoothness are the `wallpaperOptions` of [config/Apps.qml](../config/Apps.qml), any `awww img` options.

## Zoom

The magnifier icon in the bar zooms the whole screen through Hyprland's own `cursor:zoom_factor`, around the pointer.
The wheel over the icon zooms in and out, a click zooms back out, and while zoomed the factor shows next to the icon and in an OSD.
In the settings' **Bar widgets** category, its **Zoom** tab sets the maximum zoom, the zoom step (one wheel notch, or one `zoomIn` / `zoomOut` call) and **Block apps while zoomed**: the screen is then look-only, the apps underneath don't react to the pointer or keys (the wheel zooms, a click or Escape zooms out, Hyprland's own keybinds still work).
It can be driven from Hyprland keybinds with the `zoom` calls of [IPC](ipc.md).

