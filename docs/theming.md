## Themes

The theme panel (palette icon in the bar, or the IPC call below) lists **Automatique**, ten fixed themes (Catppuccin, Dracula, Nord, Gruvbox, Tokyo Night, Solarized, One, Rosé Pine, Everforest and Kanagawa) and **Custom**.
Each card shows its theme as it would be used, with the settings' mode, accent and widget background; the centered card also lists its five colors and the three derived from them (the outline of surfaces, the separator and the warning color) with their values.
The **Automatique** button in the top-right corner jumps to its card and applies it.
The cards are laid out as for the [wallpapers](panels-and-apps.md#wallpapers), in the style and with as many on each side as the settings' **Theme** category (its General tab) says.
Left/Right or the mouse wheel browse; **Enter** or a click applies; **Escape** or a click outside closes.
The choice is saved in `config/ThemeState.json` (git-ignored) and restored on startup.

- **Automatique** uses the palette matugen generates from the current wallpaper (below).
- A fixed theme ignores the wallpaper, which is only remembered for when you switch back to Automatique.
  Each has a dark version and, when the theme has an official one, a light version, used when the settings' **Theme** mode is Light: Catppuccin Mocha / Latte, Gruvbox Dark / Light, Tokyo Night / Day, Solarized Dark / Light, One Dark / Light, Rosé Pine / Dawn, Everforest Dark / Light and Kanagawa / Lotus (Dracula and Nord are dark only).
  Its accent is one of the theme's own accents, picked in the settings by the color it is (blue, purple, pink, red, orange, yellow, green, cyan), so it stays a purple accent, say, from one theme to the next; a theme without that color uses its own default.
- **Custom** uses the five colors set in the settings' **Theme** category (its Custom theme tab), typed as `#rrggbb` or picked with the color picker their dot opens; **Copy its colors** starts them from the theme in use.
  It is as light or as dark as its background.

To add or edit a theme, change the list in [config/ThemePresets.qml](../config/ThemePresets.qml): each version defines four of the five colors of [matugen/quickshell-theme.json.template](../matugen/quickshell-theme.json.template) and its accents, by color name, with the default one.
The palettes are the themes' published colors, as they were written in; check them against the theme's own page before relying on one.

## Theming with matugen

Colors come from `config/GeneratedColors.json`, which matugen writes from the current wallpaper. The file is git-ignored; until it exists, the defaults in [config/GeneratedColors.qml](../config/GeneratedColors.qml) are used.

[matugen/quickshell.toml](../matugen/quickshell.toml) is a dedicated matugen config holding this shell's templates (its palette, and the colors of Hyprland, [Zen](#zen-browser), [alacritty](#alacritty), [GTK](#gtk), [Qt](#qt) and starship), so applying a wallpaper or a theme doesn't also re-theme every app in your global `~/.config/matugen/config.toml`.
[services/Matugen.qml](../services/Matugen.qml) runs it:

- applying a wallpaper regenerates everything from it when **Automatique** is selected; a fixed theme ignores the wallpaper, which is only remembered;
- selecting a theme regenerates everything: from the wallpaper for **Automatique**, or from the theme's accent color for a fixed or custom one, in the theme's mode (light for a light version).
  With **Exact colors in the other apps** on (the default), the apps' templates then use the theme's own background, text, widget, border and accent colors for those roles, and matugen's palette around the accent only for the others (the terminal's ANSI colors, error, ...), so they match the shell exactly;
- changing a setting of the settings' **Theme** category the colors are made from regenerates everything, a second after the last change (so dragging a slider runs matugen once, not at every step), unless the colors are back to what they were made with: the mode, the Automatic theme's palette style, starting color, contrast and background lightness, a fixed theme's accent and widget background, the custom theme's colors, and **Exact colors in the other apps**.
  A fixed theme's apps get matugen's default style around its accent, whatever the Automatic theme's style.
  The Automatic theme's accent and widget background need no run: `config/GeneratedColors.json` holds every candidate and the shell picks from them;
- adding an app in the settings' **Theme** category (its Other apps tab), with its template and output file, or changing or turning on an added one, also regenerates everything; the script writes a `[templates.addedN]` section for each in `matugen/active.toml`;
- turning an app on in the settings' **Theme** category (its Other apps tab) regenerates everything, with any theme, so it gets the current colors now;
  one turned off is left out of the runs (the shell runs matugen through [scripts/matugen-run.py](../scripts/matugen-run.py), which writes `matugen/active.toml` without the other apps' templates) and keeps the colors it last got.
  Turning Hyprland off also means a run no longer makes Hyprland reload its config;
- restoring the last wallpaper when the shell starts only regenerates the colors if the theme, the wallpaper or its file, or the Automatic theme's settings changed since the last run (remembered in `config/ThemeState.json`): rewriting `~/.config/hypr/colors.lua` makes Hyprland reload its config, which would otherwise happen on every start of the shell for nothing.
  `ipc call wallpapers applyLast` always regenerates them.

A fixed theme has no image, only five colors, so matugen builds a full palette around its accent: the apps get colors in the theme's family, not its exact palette (Dracula's purple accent gives a purple-tinted dark background, not Dracula's own `#282a36`).
The shell itself always uses a fixed theme's exact colors.
Every run also rewrites `config/GeneratedColors.json`, which **Automatique** reads: while a fixed theme is selected it holds that theme's palette, so the "Automatique" card of the theme panel previews those colors, not the wallpaper's, and selecting **Automatique** regenerates it from the wallpaper (the shell shows the previous palette until matugen has finished, about a second).
The last wallpaper is remembered in `config/ThemeState.json` for that; until a wallpaper has been applied once, that state is empty and selecting **Automatique** regenerates nothing.

The config is used straight from the checkout, with template paths relative to the file, so nothing has to be copied into `~/.config/matugen` and the checkout can live anywhere.
Don't also declare these templates in your global `config.toml`, or a plain `matugen image …` would write them a second time.

A template for an app added in the settings is any file in matugen's template syntax: `{{colors.primary.default.hex}}` is replaced with the palette's primary color, `{{colors.background.default.hex}}` with its background, and so on (see matugen's documentation for every color and format).
To follow **Exact colors in the other apps** like the built-in templates, write a role as `<* if {{olshell.exact}} *>{{olshell.background}}<* else *>{{colors.background.default.hex}}<* endif *>`: the shell passes a fixed or custom theme's own colors as `olshell.background`, `text`, `textVariant`, `pill`, `pillLow`, `pillHigh`, `border`, `accent` and `onAccent` (the header of [matugen/quickshell.toml](../matugen/quickshell.toml) lists them).
The command after runs through the shell once the file is written, e.g. to have the app reload it.

## Zen browser

[matugen/quickshell.toml](../matugen/quickshell.toml) also has a template, [matugen/zen-theme.css.template](../matugen/zen-theme.css.template), which colors [Zen browser](https://zen-browser.app)'s interface — tabs, sidebar, URL bar, panels and the window background — with the theme the shell is using, so the browser follows the wallpaper and theme changes along with the bar.
Turn Zen off in the settings' **Theme** category (its Other apps tab) if you don't use it.
Zen follows its own light or dark mode, whatever the Automatic theme's mode: the template gives it both variants of each color.

It writes `userChrome.css` into the Zen profile, which is the one place in that file that has to be edited for your machine: `output_path` points at the profile marked `Default=1` in `~/.config/zen/profiles.ini`.
Firefox ignores `userChrome.css` unless one pref is on, so the profile also needs a `user.js` containing:

```js
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
```

Zen reads `userChrome.css` once, at startup: applying a wallpaper or a theme re-writes the file, but the browser only picks up the new colors the next time it starts (quit it completely first: launching it again while it runs only opens a window in the old process).

The template sets Zen's accent color (`--zen-primary-color`, which every other `--zen-colors-*` value is mixed from) and the surfaces Zen hardcodes rather than deriving from it, all in `!important` because Zen writes some of them as inline styles.
It replaces the workspace background chosen in Zen's settings.
Web pages aren't touched — this colors the browser, not what it displays.

## Alacritty

[matugen/quickshell.toml](../matugen/quickshell.toml) also has a template for alacritty, [matugen/alacritty-theme.toml.template](../matugen/alacritty-theme.toml.template), which writes the terminal colors (foreground, background, cursor, selection and the 16 ANSI colors) to `~/.config/alacritty/theme.toml`.
Import that file from your `alacritty.toml`:

```toml
[general]
import = ["~/.config/alacritty/theme.toml"]
```

Alacritty reloads imported files while it runs, so open terminals recolor as soon as the wallpaper or theme changes, with no restart (unlike [Zen](#zen-browser)).
Turn alacritty off in the settings' **Theme** category (its Other apps tab) if you don't use it.
The same goes for Hyprland (writes `~/.config/hypr/colors.lua`) and starship (writes `~/.config/starship/starship.toml`, **replacing** that file: keep your prompt's layout in the template).

## GTK

[matugen/gtk-theme.css.template](../matugen/gtk-theme.css.template) only defines the GTK named colors (window, view, header bar, sidebar, card, dialog and popover backgrounds, accent, ...) from the shell's palette; GTK builds the widgets from them.
[matugen/quickshell.toml](../matugen/quickshell.toml) writes it for each kind of GTK app:

- **libadwaita apps** (Nautilus and most GNOME apps) read it as `~/.config/gtk-4.0/gtk.css` (`[templates.gtk4]`), whatever GTK theme is set. They pick up new colors as they start.
- **GTK3 apps and plain GTK4 ones** (Blueman, nm-applet, pavucontrol, HandBrake...) get it through the **olShell** GTK theme, which matugen writes to `~/.local/share/themes/olShell/`: [adw-gtk3](https://github.com/lassekongo83/adw-gtk3)-dark (built on those names;
  adw-gtk3 while the Automatic theme's mode is Light) followed by these colors, for GTK3 (`gtk-3.0/`) and GTK4 (`gtk-4.0/`), from [gtk3-theme-index.css.template](../matugen/gtk3-theme-index.css.template) and [gtk4-theme-index.css.template](../matugen/gtk4-theme-index.css.template).
  Running apps never re-read a `gtk.css`, but they do reload their theme as its name changes, so a hook switches the name away and straight back after each run: open windows recolor at once.

To set it up:

- Install adw-gtk3 (`adw-gtk-theme` on Arch), run a theme or wallpaper change once so matugen writes the olShell theme, then select it: `gsettings set org.gnome.desktop.interface gtk-theme olShell`, and `gtk-theme-name=olShell` in `~/.config/gtk-3.0/settings.ini`.
  Restart already running GTK apps once.
- Don't keep a `~/.config/gtk-3.0/gtk.css`: an app reads it as it starts, above the theme, so it would pin that moment's colors.
- `~/.config/gtk-4.0/gtk.css` and `gtk-dark.css` must not be symlinks to a GTK theme (as `nwg-look`'s "export GTK4 symlinks" option or a theme installer leaves them): matugen would write through the link into the theme's own file, fail if it isn't yours, and stop the whole run there.
  Remove the links (and turn that option off); libadwaita prefers `gtk-dark.css` in dark mode, so a leftover one also hides the generated colors.
- Set the `org.gnome.desktop.interface color-scheme` to `prefer-dark` so the apps use the dark variant the palette is generated for (`gsettings set org.gnome.desktop.interface color-scheme prefer-dark`), or to `prefer-light` if you set the Automatic theme's mode to Light.
  The shell doesn't change it.
- Turn GTK off in the settings' **Theme** category (its Other apps tab) if you don't want GTK apps themed.

## Qt

[matugen/qt-colors.conf.template](../matugen/qt-colors.conf.template) is a Qt color scheme (a color for each palette role: window, base, button, highlight, tooltip, ... for active, inactive and disabled widgets) from the shell's palette, the same roles as [GTK](#gtk)'s.
[matugen/quickshell.toml](../matugen/quickshell.toml) writes it as the **olShell** color scheme of [qt6ct](https://github.com/trialuser02/qt6ct) (`~/.config/qt6ct/colors/olShell.conf`, for Qt6 apps) and of [qt5ct](https://sourceforge.net/projects/qt5ct/) (`~/.config/qt5ct/colors/olShell.conf`, for Qt5 apps).
Running apps re-read their qt5ct / qt6ct settings a few seconds after that folder changes, so a hook touches `qt5ct.conf` / `qt6ct.conf` after each run: open windows recolor about three seconds later.

To set it up:

- Install qt6ct (and qt5ct for Qt5 apps), and have Qt apps use it: `env = QT_QPA_PLATFORMTHEME,qt6ct` in the Hyprland config (`qt5ct` instead for Qt5 apps, which only load their own). Log out and back in.
- Run a theme or wallpaper change once so matugen writes the olShell color scheme, then in qt6ct (and qt5ct) set the style to **Fusion** (it draws everything from the palette), check **Custom** under Palette, pick **olShell** and apply.
  Restart already running Qt apps once.
- KDE apps (Dolphin, Kate...) read KDE's own color schemes for part of their colors, so they are only partly themed.
- Turn Qt off in the settings' **Theme** category (its Other apps tab) if you don't want Qt apps themed.
