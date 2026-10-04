## Settings

The gear icon in the left part of the bar, or `quickshell -p . ipc call settings toggle` (bind it to a key), opens a settings panel where the look of the shell can be adjusted live; every change applies immediately and is remembered in `config/Settings.json` (git-ignored; the language is remembered as before).
The settings, with their range:

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
| Bar widgets (Layout tab) | The bar's layout, arranged by dragging (see below): a lane per zone of the bar (left, center, right) with its groups in bar order, each group one cell holding its widgets, a lane of the widgets that are off and a lane of the ones that are disabled. Drag a widget into a group to join it, between groups (or into an empty lane) to start a group of its own, or to Off to turn it off; drag a group by its handle (󰇛) to move it with its widgets and mode, or to Off; a line shows where the drop goes. Each group's button switches it between shown (󰈈), shown on hover (󰍽) and hidden (󰈉). The settings button can't be turned off | — | the original layout |
| Bar widgets (Side-bar look tab) | Side-bar look, also on a top or bottom bar: CPU, RAM, Disk and Volume as a ring around their icon filled to their value, Network as a ring around each arrow filled to its speed against the last minute's highest (at least 1 MiB/s) (the figures move to their popup), Window title as its icon only (the title on hover); on a left or right bar they always look this way | on / off button for each | all off |
| Bar widgets (Clock tab) | Clock: date (each choice shown as today's date written that way, in the current language) | Long (Sunday, September 27, 2026) / Short (Sun, Sep 27) / Numeric (09/27/2026) / No date | Long |
| Bar widgets (Clock tab) | Clock: show seconds (without them the clock, and the bar, only update once a minute) | check box | on |
| Wallpaper | Wallpaper transition | Fade / None / From left / From right / From top / From bottom / Wipe / Wave / Grow / From center / To center / From anywhere / Random | Fade |
| Wallpaper | Transition duration | 0.5 – 10 s | 2 s |
| Wallpaper | Carousel style (how the wallpaper panel lays out the wallpapers: the selected one large and in front, the others overlapping behind it, smaller and darker the further they are, turned toward it in 3D (Cover flow, or a little: Gentle tilt), facing you (Flat fan) or fanned out and dropping like a hand of cards (Deck of cards); or all side by side, the selected one grown (Side by side)) | Cover flow / Gentle tilt / Flat fan / Deck of cards / Side by side | Gentle tilt |
| Wallpaper | Wallpapers on each side of the selected one in the wallpaper panel (stacked, fewer spread out more and overlap less) | 1 – 5 | 3 |
| Theme (General tab) | Mode (dark or light: the Automatique palette, matugen's `--mode`, and the fixed themes that have a light version; for a light theme the olShell GTK theme is built on adw-gtk3 instead of adw-gtk3-dark, see [GTK](theming.md#gtk); disabled for a theme with no light version and for the custom theme) | Dark / Light | Dark |
| Theme (General tab) | Widget background (the color of the shell's widgets, popups and panels: for Automatique one of matugen's surface colors, `surface_container_lowest` to `_highest`, needing no matugen run; for the other themes their own, moved toward the background or the text) | Closest to the background / Close to the background / Normal / Raised / Most raised | Normal |
| Theme (General tab) | Carousel style of the theme panel (as for the [wallpaper panel](#settings)'s) | Cover flow / Gentle tilt / Flat fan / Deck of cards / Side by side | Gentle tilt |
| Theme (General tab) | Themes on each side of the selected one in the theme panel | 1 – 5 | 3 |
| Theme (Automatic theme tab) | Palette style (how matugen builds the palette from the wallpaper, its `--type`) | Tonal (calm) / Content (close to the wallpaper) / Fidelity (closest to the wallpaper) / Vibrant / Expressive / Fruit salad / Rainbow / Neutral / Monochrome | Tonal |
| Theme (Automatic theme tab) | Starting color (which of the wallpaper's colors the palette is built around: every color of it, not only the accent) | Most saturated / Most common / Least saturated / Darkest / Lightest | Most saturated |
| Theme (Automatic theme tab) | Contrast (matugen's `--contrast`; its values below 0 make the text too dim to read, so they're left out) | Standard – +100 % | Standard |
| Theme (Automatic theme tab) | Background lightness (matugen's `--lightness-dark` or `--lightness-light`, scaled to what stays usable in the mode: from about -0.1 to +0.2 in dark, -0.2 to +0.05 in light; further, the background and the pills turn the same pure black or white) | -100 % (darker) – +100 % (lighter) | Standard |
| Theme (Automatic theme tab) | Accent color (which of the palette's colors the shell uses as its accent, each shown in its color; the shell only, the other apps keep theirs, and it needs no matugen run) | Primary / Secondary / Tertiary | Primary |
| Theme (Fixed themes tab) | Accent color (the theme's own accents, as color dots; kept from one theme to the next by the color it is, e.g. purple is Catppuccin's mauve and Dracula's purple, and a theme without that color uses its own) | The theme's own / blue / purple / pink / red / orange / yellow / green / cyan, those the theme has | The theme's own |
| Theme (Fixed themes tab) | Exact colors in the other apps (a fixed or custom theme's apps get its background, text, widget, border and accent colors, instead of the palette matugen builds around its accent; see [Theming with matugen](theming.md#theming-with-matugen)) | check box | on |
| Theme (Custom theme tab) | Background, widget background, border, text and accent (typed as `#rrggbb`, or picked by clicking the color dot before each: a square of saturation and brightness for a hue picked on a bar, applied as you drag, or **From the screen**, which runs hyprpicker (`screenColorPicker` in [config/Apps.qml](../config/Apps.qml)) to click a color anywhere, the settings panel hiding meanwhile and coming back where it was, with the picker closed; a mistyped color keeps the one there was), and **Copy its colors** (start from the theme in use) | any color | Catppuccin Mocha's |
| Theme (Other apps tab) | Other apps themed with the shell (with any theme; one turned off keeps the colors it last got, and turning one on colors it now; see [Theming with matugen](theming.md#theming-with-matugen)) | Hyprland / Zen / Alacritty / GTK / Qt / Starship, each on or off | all on |
| Theme (Other apps tab) | Added apps (each an app with a matugen template of your own: on / off, its name, the template file, the file matugen writes from it and a command run after, e.g. to reload the app; **Add** adds one and a bin removes it; an app without a template or an output file, or whose template can't be read, is left out of the runs instead of making them fail; the template uses matugen's syntax, and can use the shell's own data too, see [Theming with matugen](theming.md#theming-with-matugen)) | any | none |
| Notifications | Pop-up duration | 2 – 30 s | 4 s |
| Notifications | Pop-ups at once | 1 – 8 | 4 |
| Notifications | Notification position (a list of small screens with a block where the pop-ups go, and the name) | Top right / Top center / Top left / Right center / Left center / Bottom right / Bottom center / Bottom left | Top right |
| Notifications | Do not disturb | check box | off |
| OSD (General tab) | Position of every OSD that follows it (a list of small screens with a block where the popup goes, and the name; also the volume pill on the lock screen, when the volume OSD follows it) | Bottom center / Bottom left / Bottom right / Center / Left center / Right center / Top center / Top left / Top right | Bottom center |
| OSD (General tab) | Distance from the edge (from the edges it is placed against; at the top or bottom on the bar's side, from the bar; disabled while the position is Center) | 0 – 400 px | 60 px |
| OSD (Volume tab) | Same as every OSD (follow the General tab's position and distance; off: the two below) | check box | on |
| OSD (Volume tab) | Position, its own (also the volume pill on the lock screen) | as in the General tab | Bottom center |
| OSD (Volume tab) | Distance from the edge, its own | 0 – 400 px | 60 px |
| OSD (Caps Lock / Num Lock tab) | Same as every OSD (as for the volume) | check box | off |
| OSD (Caps Lock / Num Lock tab) | Position, its own | as in the General tab | Bottom right |
| OSD (Caps Lock / Num Lock tab) | Distance from the edge, its own | 0 – 400 px | 60 px |
| Lock screen | Lock after (minutes without keyboard or mouse input) | never, 1 – 60 min | 8 min |
| Lock screen | Stay awake in fullscreen (while the focused window is fullscreen, a game or a film, the screen neither locks nor blanks by itself) | check box | on |
| Launcher | Default tab (the one the launcher opens on) | All / Applications / Games / Files / Web / Web apps | All |
| Launcher | Results shown (the most the list shows at once, the launcher shrinking to fewer; more scroll) | 3 – 20 | 10 |
| Launcher | History length (the applications and games last opened from the launcher, listed first with an empty search; 0: none) | 0 – 10 | 3 |
| Launcher | Web search engines (on / off, name, address with `%s` where the search goes, order; add and remove) | any; the browser's default engine can be turned off and moved, not removed | the browser's default engine, YouTube, Wikipedia |
| Web apps | Command opening a web app: a program and its arguments, `%s` standing for the address (added at the end without one); run without a shell, quotes grouping words | any; empty puts the default back | `zen-browser -P webapp --new-window %s` |
| Web apps | Web apps (on / off, the off ones left out of the bar widget's menu; name, web address, order; add and remove) | any name, an `http(s)://` address | none |
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
| Chat AI | The shell: read its documentation (this documentation, searched and read a part at a time) and its current settings, and run its commands (the IPC calls, all but those that can't be undone, see [Chat AI](chat-ai.md#chat-ai)) | Read its documentation and settings / Run its commands | documentation on, commands off |
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

**The bar's layout.** The **Layout** tab of the **Bar widgets** category shows the bar as three lanes, **Left**, **Center** and **Right**, each holding its groups in bar order, and a lane of the widgets that are **Off** (launcher, settings button, workspaces, window title, clock, wallpaper, theme, screenshot, zoom and keyboard shortcuts buttons, tray, CPU, RAM, disk, network, network connection, Bluetooth, volume, notifications, lock, power, chat AI, web apps).
The widgets of a pill are split into **groups** by dividers: a group starts at the first widget of a pill and at each widget with a divider before it, and is drawn as one cell holding its widgets.
Drag a widget into a group to join it where you drop it, between groups (or into an empty lane) to start a group of its own there, or to **Off** to turn it off (turned on again from the IPC call, it goes back where it was);
drag a group by its handle (󰇛) to move it, with its widgets and mode, anywhere in a lane, or to **Off** to turn all its widgets off.
A line shows where the drop goes.

**Disabled.** A widget dropped on the **Disabled (not loaded)** lane is off the bar like an **Off** one, and its whole feature is unloaded too: the widget, its panel or popup, its service, its OSD and its IPC calls, which no longer exist (`ipc show` doesn't list them).
Drag it back into a lane, or run `settings widgetEnabled <widget> 1`, to load it again where it was.
The settings button can't be disabled.
What each widget takes with it:

- `launcher`, `theme`, `wallpaper`, `shortcuts`, `chatAi`, `power`, `clock`: their panel and its IPC target (`wallpaper` also stops the saved wallpaper being restored at startup, `clock` the `weather` calls, `power` its confirmation).
- `notifications`: the notification pop-ups, the center and the rules panel, and the notification server itself, which gives up the D-Bus name.
- `volume`: the volume OSD and the `volume` calls.
- `zoom`: the zoom OSD, its look-only shield and the `zoom` calls, and the screen goes back to no zoom.
- `screenshot`, `disk` (`gdu`), `webApps`, `lock` (the lock screen and idle timer, and `lock` calls): their `screenshot`, `gdu`, `webApps` and `lock` calls.
- `cpu`, `ram`, `network`: the `btop` calls, once all three are disabled.
- `workspaces`, `activeWindow`, `tray`, `connection`, `bluetooth`: only the widget itself.
Each group's button switches its mode: shown (󰈈), off and never shown (󰈉, its widgets stay in the group so it can be turned on again), or shown only on hover (󰍽): while the pointer is over its pill its widgets slide open, and shut again half a second after you leave it (the group of a widget whose popup is showing, such as the clock, stays open until the popup closes, so the popup keeps its anchor).
A divider only shows when its widget does and something shown comes before it in the pill, so there is none at the start of a pill or for a widget with nothing to show (the window title when no window is open);
a pill with nothing left in it disappears, a pill whose groups are all on hover keeps a small dots icon to hover, and a pill whose groups are all off is not drawn.
By default there is a divider before every widget except the launcher, the settings button, the clock and the tray, which is how the bar looked before this was adjustable.
The settings button can go anywhere but off, so this panel stays reachable by clicking.
The layout is saved as three lists (`barLeft`, `barCenter`, `barRight`), the widgets with a divider before them (`barDividers`) and the widgets starting a group shown only on hover (`barCollapsed`) or off (`barGroupsOff`), and the disabled widgets (`barDisabled`), in `config/Settings.json`; a widget listed twice or unknown is ignored.

Bar position picks which edge of the screen the bar is anchored to.
Either way, the top and bottom margins keep their own meaning: whichever is on the side the bar is anchored to is the gap between the bar and that edge, and the other becomes extra room kept free on the far side of the bar (the bar reserves its height plus this much, so windows start that much further away), on top of your compositor's own gaps;
at 0 the layout is what it was without the setting.
Popups that open from the bar's own widgets (the clock, the tray, a widget's tooltip) open upward instead of downward when the bar is at the bottom, so they always open toward the middle of the screen.
The text settings apply to all text and icons in the shell: the weight is what the font offers (a font without that weight uses the nearest it has), the outline is drawn in the accent color, and letter spacing and capitalization change the width of the text (so the bar's contents move).
The settings are grouped in categories, shown as a column of buttons on the left of the panel, each an icon with its name (appearance, text, top bar, bar widgets, wallpaper, notifications, OSD, lock screen, launcher, panels, chat AI, general); click one to show its settings, whose name is the panel's heading.
**Appearance** has three tabs under its name: **General** (the widgets' look, the gap and the curved joins), **Blur** (the blur and Hyprland's blur options) and **Windows** (Hyprland's window look, synced with the shell's on request).
**Bar widgets** has a **Layout** tab (the bar's layout, below) and a tab for each widget with settings of its own, named after it (**Workspaces**, **Side-bar look**, **Clock**, **Zoom**);
so does **Panels**: **Placement** (where each panel opens) and a tab for each panel with settings of its own, named after it (**App switcher**, **Clock**);
click one, or press **Tab / Shift+Tab**, to switch.

The panel is 920 px wide, or wider (within the screen) when the widest row of the category needs it, as with the longer French names, so it follows the language, the font size and the font.
A category with more rows than fit (the widgets, mostly) scrolls: with the wheel, or by moving the selection with the keys, which keeps it in view.
Click or drag a slider (the font, the wallpaper transition and the pop-up position each open a list: click an entry to pick it, or scroll for more;
the fonts are drawn in their own font, the positions with a small screen icon), or use the keys: **↑/↓** select a row, **←/→** adjust it (**Shift** for bigger steps), **Page Up/Page Down** switch category, **Tab/Shift+Tab** go through everything on the page one by one (each button, check box and field of a row, then the next row, around at the ends), **Ctrl+Tab/Ctrl+Shift+Tab** switch tab (in the categories that have tabs), **Enter** opens the list of a font, transition or position row (then **↑/↓**, **Page Up/Page Down**, **Home/End** move in it, **Enter** picks, **Escape** closes just the list);
on the font style row, **←/→** move between the buttons and **Enter** (or **Space**) switches one, **Escape** closes.
**Reset** (top right, next to the category's name) puts that category (or that tab) back to your own defaults, or to the built-in ones for any setting you saved none for.
**Defaults:** the last row of each category (and of each tab) has two buttons: **Save as my defaults** remembers the category's current values as your own defaults (in `config/UserDefaults.json`, git-ignored;
for the widgets category that is the whole bar layout, and for General the language too), and **Factory defaults** puts the category back to the built-in ones, whatever you saved, and saves them as your defaults too, so Reset then does the same: it first asks for a confirmation in the row itself (**Confirm** or **Cancel**;
Cancel is the one the keys are on, and Escape cancels).
The built-in defaults are in [config/Defaults.qml](../config/Defaults.qml), which nothing writes to, so they are always there to go back to.
On the keys, **←/→** move to a button and **Enter** presses it.
The General category also has an **All categories** row with a **Factory defaults** button that does the same for every category and the language: it asks first (**Confirm** or **Cancel** in the row; Escape cancels), then puts everything back to the built-in values, saves them as your defaults and forgets where turned-off widgets were.
(`settings factoryReset` does it from a script, without asking.)
Neither the font size nor the icons (tray and active window) depend on the bar height, so a large font in a low bar can overflow the pills, and a very tall bar with big margins can make the bar's three groups collide.

Values live in [config/Settings.qml](../config/Settings.qml), which `Theme` reads, so to make another value adjustable add it there (its built-in default in [config/Defaults.qml](../config/Defaults.qml), limits, property), point `Theme` at it, and add a row (with its `category`) in [modules/Settings/SettingsPages.qml](../modules/Settings/SettingsPages.qml) and its label in [config/Translations.qml](../config/Translations.qml).

### From a script

Every call is `quickshell -p . ipc call settings <command> …`.

- `set <key> <value>`: a number setting (out-of-range values are clamped) or a yes/no one (1 or 0), see below.
- `choose <key> <value>`: a setting with a list of choices (a value not in the list is ignored), a color or a text, see below.
- `get <key>`, `getChoice <key>` (for the font family and capitalization too).
- `open <page>`: open the settings panel on a page, named as for `saveDefaults` (their ids are in `map`), or on a category with tabs by its first tab's name.
- `map`: the settings panel's map as JSON: its pages (id and name, as `Category > Tab`), each setting's page and name there, and each bar widget's name, in the current language.
- `reset`: every category, to your defaults.
- `saveDefaults <category>`: save a category's current values as your defaults.
- `restoreDefaults <category> <mine|factory>`.
- `factoryReset`: every category and the language, to the built-in values, without asking.
- The bar's layout:
  - `place <widget> <zone> [position]`: zone `left`, `center`, `right` or `off`; position from 0, or -1 for the end.
  - `widgetShown <widget> <1|0>`: put a widget on the bar, back where it was, or take it off.
  - `widgetEnabled <widget> <1|0>`: enable a widget (loaded again, back where it was) or disable it (off the bar, and its feature and IPC calls unloaded). `place` on a disabled widget enables it.
  - `move <widget> <steps>`: negative for earlier.
  - `divider <widget> <1|0>`: the divider before a widget.
  - `group <widget> <on|hover|off>`: the mode of the group that widget is in.
  - `moveGroup <widget> <steps>`: move the group that widget is in earlier or later in its pill.
  - `layout`: prints the layout and dividers as JSON.
- The web apps: `webApps` (prints them as JSON), `addWebApp <name> <url>`, `removeWebApp <index>`, `moveWebApp <index> <steps>`, `webAppOn <index> <1|0>` (index from 0).

**Keys, kinds and values.** `map` lists everything the calls above take, in the current language, so nothing here goes stale:

```sh
quickshell -p . ipc call settings map | jq -r '.settings | to_entries[] | "\(.key)  \(.value.kind)  \(.value.range // "")  \(.value.name)"'
quickshell -p . ipc call settings map | jq '.choices.barPosition'   # the values of a choice
quickshell -p . ipc call settings map | jq -r '.pages[].id'         # the pages saveDefaults, restoreDefaults and open take
quickshell -p . ipc call settings map | jq -r '.widgets | keys[]'   # the widgets place and the layout calls take
```

Each setting has a `kind`:

- `number` (`set`): clamped to its `range`; `fontWeight` is rounded to hundreds.
- `yes/no` (`set`, 1 or 0).
- `choice` (`choose`): a value not in its list in `choices` is ignored.
- `color` (`choose`): a `#rrggbb` color (`customBackground`, `customPill`, `customBorder`, `customText`, `customAccent`).
- `list`: the bar's layout, the web apps and the other lists, which have calls of their own (above) or are edited in the panel, not set with `set` or `choose`.
- `text` (`choose`):
  - `weatherLocation`: a place's name (`""` for automatic).
  - `webAppCommand`: the command opening a web app, `%s` for its address (`""` for the default).
  - `chatAiDefaultProvider`: a chat AI provider's id (`anthropic`, `openai`, or an added one's), `""` for the first one that can be asked.
  - `fontFamily`: any installed font family, e.g. `settings choose fontFamily "DejaVu Sans Mono"`.
    The panel's list only has the Nerd Font families, since the icons are Nerd Font glyphs.
    Qt only reads the installed fonts when the shell starts, so restart the shell after installing or removing one.

`panelPlacement` is a choice of its own: it takes the panel placements (`center`, `center-left`, `center-right`, `bar-left`, `bar-center`, `bar-right`, `opposite-left`, `opposite-center`, `opposite-right`) and sets every panel's placement at once; `getChoice` gives theirs when they all match, `each` otherwise.

The wallpaper transition and its duration apply the next time a wallpaper is applied (they are the `awww img` `--transition-type` and `--transition-duration`), including when the shell restores the last one at startup.

## Localization

The shell speaks **English**, **French** and **Spanish**.
By default it follows the system language (`LC_ALL`, `LC_MESSAGES` or `LANG`; English if that isn't one of them).
The language can be chosen in the settings panel (General), and the choice is remembered in `config/LocaleState.json` (git-ignored).
It can also be set from a key binding or a script (`toggle` goes to the next language, English → French → Spanish):

```sh
quickshell -p . ipc call language set es      # or en, fr, or auto to follow the system again
quickshell -p . ipc call language toggle
quickshell -p . ipc call language get
```

Everything is switched at once: texts, dates and month/day names, decimal separators, and units (Gio / GiB). The week still starts on Monday in both.

The launcher's application names, descriptions and keywords follow the shell's language too, not the system's: every `.desktop` file carries all its translations (`Comment[fr]=...`), so [services/DesktopLocale.qml](../services/DesktopLocale.qml) reads them straight from the files (the user's and system's `applications` directories, in priority order) and picks the best one for the current language (`language_COUNTRY`, then `language`, then the untranslated text), instead of the single language Quickshell reads at startup.
Searching matches the translated name and keywords as well as the untranslated name ("files" still finds Fichiers).
The files are read again each time the launcher opens; an application with no readable file falls back to Quickshell's own text.

The texts are in [config/Translations.qml](../config/Translations.qml), one dictionary per language with dotted keys (`power.logout`); [config/I18n.qml](../config/I18n.qml) looks them up with `I18n.tr("key", args...)`, replacing `{0}`, `{1}`... and choosing between `one` / `other` forms for counts.
A key missing from a language falls back to English, then shows the key itself.
To add a language: add a dictionary with the same keys as `en` (including `format.locale`, `format.decimal`, `format.units`, `format.date.long`, `format.date.short`, `format.date.numeric`, `format.time`, `format.timeSeconds`) and list its code in `I18n.supported`.
Use `I18n.tr` for any new visible text rather than a literal.
