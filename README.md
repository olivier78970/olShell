# olShell

olShell is a [Quickshell](https://quickshell.org) shell for Hyprland: a top bar replicated on every monitor, bar widgets whose left click runs a command you choose (btop, gdu... in a terminal window, or any application), pavucontrol for the audio mixer (click the volume widget), an application launcher, a wallpaper picker and a theme picker (automatic from the wallpaper, one of 10 fixed themes with their light versions, or your own colors), a clock popup with an agenda and performance figures, live CPU / RAM / network-speed widgets, a volume OSD, a screenshot button, a notification center with pop-ups, a Caps Lock / Num Lock OSD and a lock screen (by idle timer or a button), a power panel with confirmation, all in English, French or Spanish.

## Requirements

The versions it runs on are Quickshell 0.3, Hyprland 0.56 and matugen 4.2; older ones may lack what it uses (noted below). Package names are Arch's where they differ.

Needed:

- [Quickshell](https://quickshell.org), with its Hyprland, Wayland, PipeWire, notifications, PAM, polkit, system tray, Bluetooth and networking modules (all in the standard build)
- Hyprland with its Lua config: the shell sets things at run time with `hyprctl eval` (zoom, blur, the synced window look, `QS_CONFIG_PATH`), and the shortcuts panel reads the config's `hl.bind(...)` calls
- Python 3, standard library only, for the helpers in `scripts/`
- the Adwaita icon theme (`adwaita-icon-theme`), where the shell looks up the apps' icons (an app whose icon isn't found gets a generic glyph in the launcher)
- a Nerd Font, used for text and icons: "0xProto Nerd Font" by default, changeable in the settings (see [Settings](docs/settings.md#settings))
- PipeWire (volume), PAM (lock screen), systemd (`systemctl` for restart, shut down, suspend and UEFI setup) and the usual command-line tools (`sh`, `find`, `awk`, `xargs`, `stat`, `df`, `grep`)

For the features that use them:

- [matugen](https://github.com/InioX/matugen) 4 or later (its templates use `<* if *>` conditions and data passed with `--import-json-string`) and [awww](https://codeberg.org/LGFae/awww) for the wallpaper picker and the themes (awww is the wallpaper daemon; the shell starts it when it isn't running)
- [`pavucontrol`](https://freedesktop.org/software/pulseaudio/pavucontrol/) for the audio mixer (volume click)
- `btop` and [`gdu`](https://github.com/dundee/gdu) for the default click actions of the CPU, RAM, network-speed and storage widgets, and a terminal for them and for the terminal applications started from the launcher (`alacritty` by default, configurable in [config/Apps.qml](config/Apps.qml))
- `grim` and `slurp` for the screenshot button, and optionally `wl-clipboard` (`wl-copy`, to copy the picture), `libnotify` (`notify-send`, to announce it) and [`satty`](https://github.com/gabm/satty) (to annotate it)
- [`fd`](https://github.com/sharkdp/fd) for the launcher's files (and the chat AI's file searches, with [`ripgrep`](https://github.com/BurntSushi/ripgrep) for its text searches;
  both fall back to plain Python without them), `xdg-utils` (`xdg-open` to open a file or an address, `xdg-settings` to find the default browser's search engine) and `nautilus` (to show a file in its folder)
- NetworkManager (`nmcli`) and `nm-connection-editor` for the network connection widget, and BlueZ with [blueman](https://github.com/blueman-project/blueman) for the Bluetooth widget's windows (blueman's own tray icon, whose applet starts along with those windows, is left out of the tray: `hiddenTrayItems` in [config/Apps.qml](config/Apps.qml))
- [hyprpicker](https://github.com/hyprwm/hyprpicker) for the color picker's **From the screen** (custom theme)
- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) (`adw-gtk-theme`) and `gsettings` (`glib2`) for GTK apps in the shell's colors (see [GTK](docs/theming.md#gtk))
- optionally [qt6ct](https://github.com/trialuser02/qt6ct) and [qt5ct](https://sourceforge.net/projects/qt5ct/) for Qt apps in the shell's colors (see [Qt](docs/theming.md#qt))
- `secret-tool` (`libsecret`) and a Secret Service keyring (GNOME Keyring, KWallet...) for the chat AI panel's API keys, and an account with an AI provider or a local server (see [Chat AI](docs/chat-ai.md#chat-ai))
- optionally [Zen browser](https://zen-browser.app) and [starship](https://starship.rs), which matugen can color with the shell's palette (see [Zen browser](docs/theming.md#zen-browser))

## Running

```sh
quickshell -p .
```

Or symlink/copy this directory to `~/.config/quickshell/<name>` and run:

```sh
quickshell -c <name>
```

## Documentation

- [Settings and localization](docs/settings.md): every setting, the settings panel, the `settings` IPC calls for scripts, and the languages.
- [IPC](docs/ipc.md): the calls to bind to keys.
- [Chat AI](docs/chat-ai.md): the question-and-answer panel, its providers and what the AI may read or run.
- [Theming](docs/theming.md): the themes, matugen, and Zen, alacritty, GTK and Qt colored from them.
- [Panels and apps](docs/panels-and-apps.md): the launcher, app switcher, shortcuts, clock popup, wallpapers, web apps, zoom, the widgets' click actions and the audio mixer.
- [System](docs/system.md): performance figures, network, Bluetooth, screenshots, notifications, power, the lock screen, polkit and the lock keys OSD.
- [Structure](docs/structure.md): every file and what it is for (generated from the files' own comments).
