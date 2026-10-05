## Performances

The **Performances** tab of the clock popup shows the machine's load at a glance, refreshed live:

- **Processeur** and **Mémoire**: a ring gauge with the current percentage (the CPU card adds frequency and core count, the memory card used / total), and a sparkline of the last samples.
- **Réseau**: instant download and upload speed with a sparkline of the last minute each. Only physical interfaces are counted (found through `/sys/class/net`), so a VPN or docker doesn't count the same traffic twice.
- **Stockage**: the main disk, the one mounted on `/`, with used / capacity and a usage bar.
  (`SystemStats.disks` lists every mounted disk, without pseudo file systems such as tmpfs and with a device mounted several times, e.g. btrfs subvolumes, listed once; the tab filters it to `/`.)
  Gauges and bars turn to `Theme.warningColor` above 90%.

The right part of the bar also has a disk widget (`DiskUsage`, after the RAM widget) showing how full the main disk, the one mounted on `/`, is, in percent (in the warning color above 90%); hovering it shows the used space over the capacity (e.g.
"825.8 GiB used / 915.3 GiB").
It reads the same figures as the storage card above (`SystemStats.rootDisk`, refreshed every 20 s), and clicking it runs its [click action](panels-and-apps.md#widget-click-actions) (gdu on that disk by default).
It also has an instant download / upload speed widget (`NetworkSpeed`, between the disk and volume widgets), fed by the same network figures, refreshed every second.
Its numbers have fixed widths so the bar does not shift as they change.

### Network connection

The network connection widget (`ConnectionButton`, after the network speed widget by default; a layout saved before it existed doesn't have it until you drag it into a lane in the settings' Bar widgets Layout tab, or `settings place connection right`) does what nm-applet's tray icon does, drawn like the rest of the bar.
Its icon is the wired plug, or the Wi-Fi signal (four levels), while connected, in the warning color when the connection doesn't reach the internet; crossed out and dimmed while disconnected, and a network-off icon while networking is off.
Hovering it says what it's connected to (the wired connection's name, or the Wi-Fi network and its signal) and the IPv4 address.
A click runs its [click action](panels-and-apps.md#widget-click-actions) (`nm-connection-editor` by default) and a right click opens a menu with, as in nm-applet: each wired device's connection (a click connects it) and **Disconnect**;
the Wi-Fi networks in range, the strongest eight first, with their signal and a padlock for the secured ones (the connected one lit;
a click connects: straight away to an open or known network, otherwise `nmcli --ask` asks for the password in a terminal) and **Disconnect**;
**Connect to a hidden Wi-Fi network…** (its name and password asked in a terminal) and **Create a new Wi-Fi network…** (NetworkManager's connection editor);
the VPN and WireGuard connections (a click switches one, the active ones lit) and **Add a VPN connection…**;
**Enable networking** and **Enable Wi-Fi** check marks;
**Connection information** (a popup with each active connection's interface, IPv4 and IPv6 addresses, gateway and DNS, until a click elsewhere);
and **Edit connections…** (`nm-connection-editor`).
The Wi-Fi scans while the menu is open.
It reads Quickshell's Networking module, and NetworkManager through `nmcli` for what that module doesn't have ([services/NetworkManager.qml](../services/NetworkManager.qml)), so it works without nm-applet running.
The terminal it opens is `networkTerminal` in [config/Apps.qml](../config/Apps.qml).

### Bluetooth

The Bluetooth widget (`BluetoothButton`, between the network connection and volume widgets by default; a layout saved before it existed doesn't have it until you drag it into a lane in the settings' Bar widgets Layout tab, or `settings place bluetooth right`) does what blueman's tray icon does, drawn like the rest of the bar.
Its icon is crossed out and dimmed while Bluetooth is off or there is no adapter, and shows a link while a device is connected.
Hovering it says whether Bluetooth is on and lists the connected devices, with their battery when they report it.
A click runs its [click action](panels-and-apps.md#widget-click-actions) (blueman's device manager by default); a right click opens a menu to turn Bluetooth on or off, make the adapter discoverable (or stop), disconnect each connected device, send files to a device, reconnect one of the paired devices that aren't connected, and open blueman's **Devices**, **Adapters**, **Local services** and **Plugins** windows.
It reads BlueZ through Quickshell's Bluetooth module, so it works without blueman running; the windows it opens are blueman's (the plugins one through `blueman-applet`, over D-Bus).

The figures come from [services/SystemStats.qml](../services/SystemStats.qml), which the CPU and RAM widgets share, so they're polled once however many monitors there are: CPU every 2 s, memory every 3 s, network every second, disks every 20 s.

## Screenshots

The camera button in the middle of the top bar takes a screenshot: a **left click** captures in the mode chosen last, a **right click** opens a menu to choose a mode (the current one is in the accent color), and choosing one remembers it and takes the screenshot at once (after a quarter of a second, so the menu is gone from the picture).
The modes:

- **Screen**: the focused monitor.
- **Rectangle**: draw the area with the mouse ([slurp](https://github.com/emersion/slurp)).
- **Window**: click one of the windows on show on any monitor's workspace.

The last row of the right-click menu, **Annotate with Satty**, switches an annotation step on or off (remembered; ticked and in the accent color when on).
With it on, each screenshot is also opened in [Satty](https://github.com/gabm/satty) once taken, to draw arrows, boxes, text, blur and so on: **Enter** there copies the annotated picture to the clipboard and saves it next to the original as `screenshot-<date>_<time>-edited.png`, then closes Satty (its toolbar has more save options).
The original is kept and copied first, so closing Satty without doing anything leaves you the plain picture; no notification is shown in that case, since Satty announces its own.
It needs `satty`; without it the switch does nothing.

The picture is saved as `~/Pictures/Screenshots/screenshot-<date>_<time>.png` (the folder is created;
the settings panel's General category has a **Screenshot folder** field to change it: click it or press **Enter**, type, **Enter** again to save, **Escape** to cancel;
`~` is your home folder, and anything that isn't an absolute path is refused and puts back the default), copied to the clipboard, and announced with a notification showing it.
Escape while choosing an area cancels.
[scripts/screenshot.py](../scripts/screenshot.py) does the work with `grim`, and [services/Screenshot.qml](../services/Screenshot.qml) keeps the mode (`screenshotMode` and `screenshotEdit` in `config/Settings.json`, not in the settings panel; the folder, `screenshotDir`, is) and answers the IPC calls:

```sh
quickshell -p . ipc call screenshot capture         # in the remembered mode (bind this to a key, e.g. Print)
quickshell -p . ipc call screenshot take window     # in another mode, without remembering it (screen, region or window; the argument is required)
quickshell -p . ipc call screenshot mode region     # remember a mode
quickshell -p . ipc call screenshot edit 1          # annotate with Satty afterwards (0: don't)
quickshell -p . ipc call screenshot dir ~/Shots     # where pictures go (no argument: print it)
```

The button is a bar widget like the others: it can be moved, turned off or given a divider from the settings panel's Bar widgets category.
It is in the middle of the bar by default; a layout saved before it existed doesn't have it until you put it in a pill there (or `settings place screenshot center -1`).
The clipboard copy and the notification are skipped if `wl-copy` or `notify-send` isn't installed.

## Notifications

olShell is a desktop notification server (the `org.freedesktop.Notifications` D-Bus service that `notify-send` and applications talk to), so it takes the place of mako, dunst or swaync: **only one of them can run**.
Stop the other one and keep it from starting again (for swaync: `systemctl --user mask swaync`, since it is started by D-Bus on the first notification, and remove any autostart line for it), otherwise whichever starts first keeps the name and olShell logs "Could not register notification server".

- **Pop-ups** appear on the focused screen, at the top right by default (the *Notification position* setting puts them in another corner, at the middle of the top or bottom edge or halfway down the left or right one;
  at the top they are under the bar, and the newest is always the one nearest the edge):  the icon (the notification's image, else its application icon), summary, body (basic markup and links work) and one button per action.
  They stay for the *Pop-up duration* setting, or the time the sender asked for; urgent ones stay until closed; a line along the bottom shows the time left, and the timer stops while the pointer is over the pop-up.
  At most *Pop-ups at once* are shown, the others wait their turn.
  **Click** a pop-up to run its default action (if it has one) and put it away into the center; the cross closes it for good.
- **The center** is opened by the bell in the bar (or `ipc call notifications toggle`): every notification received, by application (newest first), in a panel placed like the other panels (the settings' **Panels** category, **Placement** tab, **Notification center**: against the bar's middle by default, on the focused screen), with the time, a cross per notification and per application, and **clear all**.
  Clicking a notification with a default action runs it and closes it.
  **Escape** or a click outside closes it; opening it puts any pop-ups away, since it shows them.
- **The bell** is a bar widget like the others, just before the power button by default (a layout saved before it existed doesn't have it until you drag it into a lane in the settings' Bar widgets Layout tab, or `settings place notifications right`).
  The bell is accent-colored while the center has notifications, and red while one of them is urgent.
  Their number is written to the right of the bell: it goes down only when one is dismissed, not when its pop-up goes away.
  A **right click** switches *do not disturb* on or off (also in the center's header and the settings' Notifications category): the bell is crossed out and no pop-up shows, except for urgent notifications; everything still goes to the center.
- The history is kept in memory: it is lost when the shell restarts. A notification an application replaces (`notify-send -r`) or closes is updated or removed here too.

[services/Notifications.qml](../services/Notifications.qml) is the server and answers the IPC calls; [modules/Notifications/](../modules/Notifications) has the pop-ups, the center and the notification card.

## Power

The power icon at the end of the bar (or `quickshell -p . ipc call power toggle`, to bind to a key) opens a panel attached to the bar under it, like the theme and wallpaper pickers (centered along the focused screen's bar when opened by the IPC call), with six actions on two rows of three: **Lock**, **Suspend** and **Log out** above, **Restart**, **UEFI setup** and **Shut down** below.
**←/→** (or **Tab**) move between them, **↑/↓** switch rows, **Enter** or a click picks one, **Escape** or a click outside closes.
Picking one closes the panel; lock and suspend happen at once, the others ask for confirmation (Enter or **Confirm** runs it, Escape or **Cancel** drops it).
`ipc call power logout`, `restart` and `shutdown` skip the panel and go straight to that confirmation, so a script never powers the machine off unasked.
Logging out is Hyprland's exit; the others are `systemctl reboot` and `systemctl poweroff`.
The panel is [modules/Power/PowerPanel.qml](../modules/Power/PowerPanel.qml), the confirmation [components/PowerConfirmDialog.qml](../modules/Power/PowerConfirmDialog.qml) and the commands are in [config/PowerMenuState.qml](../config/PowerMenuState.qml).

## Lock screen

The padlock icon just before the power icon (or `quickshell -p . ipc call lock lock`, to bind to a key) locks the screen.
It is a Wayland session lock ([modules/Lock/LockScreen.qml](../modules/Lock/LockScreen.qml)): the compositor shows only the lock surfaces, one per monitor, with the time, the date and a password field over the current wallpaper, blurred and slightly darkened (the theme background when there is none), until the password is right.
Type it and press **Enter**; it is checked by PAM against your own login (the `login` stack, [services/Lock.qml](../services/Lock.qml)), so it is the password you log in with.
A wrong one says so and empties the field.
The **Lock screen** category of the settings has **Lock after**: the minutes without keyboard or mouse input before the screen locks by itself, from 1 to 60, or **never** (0); the default is 8 (`lockTimeout` in `config/Settings.json`; `settings set lockTimeout 5`).
Anything that inhibits idling (a video playing, for one) holds the timer off.
So does a fullscreen focused window while **Stay awake in fullscreen** is on (the default; `lockStayAwakeFullscreen`): games, played with a gamepad, give no input the compositor counts and seldom inhibit idling themselves.
The shell then inhibits idling itself, so an idle daemon such as hypridle doesn't blank the screen either.
`ipc call lock status` prints 1 while the screen is locked, else 0.
There is no unlock call, on purpose.

Reloading the shell (saving a file while developing it) while the screen is locked breaks the lock, and Hyprland then shows a lock-crashed message.
To get out, switch to a text console (Ctrl+Alt+F3), log in, and run `hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'` then `hyprctl --instance 0 dispatch exec hyprlock` (Hyprland's hyprlock takes the lock over and unlocks with your password);
or set `misc:allow_session_lock_restore = true` in your Hyprland config beforehand, so that starting the shell again is enough.

## Authentication (polkit)

The shell is the session's polkit authentication agent ([services/Polkit.qml](../services/Polkit.qml), through Quickshell's Polkit module): when an application asks for administrator rights (`pkexec`, a package manager or a system settings window), a dialog ([modules/Polkit/PolkitDialog.qml](../modules/Polkit/PolkitDialog.qml)) shows over the dimmed screen with the application's icon, what it wants to do, who authenticates (a choice when several administrators can) and a password field.
**Enter** or **Authenticate** sends the password; a wrong one says so and empties the field for another try.
**Escape**, **Cancel** or a click outside refuses the request. polkit accepts a single agent per session, so no other one (polkit-gnome, polkit-kde-agent...) may be started with Hyprland; while the shell isn't running, nothing can ask for the password and those requests fail.

## Lock keys OSD

Switching Caps Lock or Num Lock on or off briefly shows a popup at the bottom of the screen, where the volume OSD appears by default (the settings panel's **OSD** category places them all at once in its General tab, or each in its own tab with **Same as every OSD** unticked), with the key's icon and its new state (accent-colored when on).
The state isn't announced at startup, only on changes.

[services/LockKeys.qml](../services/LockKeys.qml) runs [scripts/lock-keys-watch.py](../scripts/lock-keys-watch.py), which polls the lock LEDs the kernel exposes in `/sys/class/leds/*::capslock` and `*::numlock` (ten times a second, from one process) and reports each change.
A lock counts as on when any keyboard's LED is on, and keyboards plugged in later are picked up.
This works on any compositor but needs those LEDs to exist, which is the case for ordinary keyboards.
