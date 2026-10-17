---
name: multi-monitor
description: How olShell handles several monitors - one bar window per screen, the focused and main monitor, where a panel opens, per-monitor workspaces, the monitor settings page - and how to test it. Use it whenever a change depends on which monitor something is on or has to work with two monitors, such as a per-monitor setting, a bar, OSD, panel or pop-up on a given screen, or "on all monitors" / "on the main monitor" behaviour, even if the user doesn't say "multi-monitor".
---

# Several monitors in olShell

A bug here shows only with two monitors and only on the monitor you are not looking at, so know which monitor each piece speaks about before writing it.

## Which monitor is meant

- **Focused monitor**: `Hyprland.focusedMonitor` (name in `.name`). `MonitorLayout.focused` (`services/MonitorLayout.qml`) is the same monitor as an object with its mode, scale, mirror and HDR; the Monitors page of the settings acts on it, and so does the workspace count slider with workspaces per monitor.
- **Main monitor**: `Matugen.mainMonitor`, the setting `Settings.mainMonitor` or else the first monitor Hyprland lists. The Automatic theme follows its wallpaper, and the monitor editor fixes it in place.
- **A window's own screen**: an item knows it through `QsWindow.window.screen`. A `Variants` over `Quickshell.screens` gives each delegate its `modelData` screen (the bar does this in `modules/Bar/Bar.qml`; the zoom OSD, the monitor identify pills and `Notifications` list the screens too).
- **A panel's screen**: `ModalPanel.targetScreen` is its anchor widget's screen, else the focused monitor's.

Don't mix them up: a setting row labelled with `MonitorLayout.focused?.name` must set that monitor, and the main monitor is not the focused one.

## Rules of thumb

- **One window per screen is memory per screen.** A bar built on a screen costs its widgets, popups and click catcher. To not have it somewhere, leave the screen out of the `Variants` model rather than hiding the window.
- **Anything that exists on only some monitors needs a fallback**: a panel attached to the bar has no bar to attach to on a screen without one, and a saved monitor name can be unplugged (treat it as unset, and fall back to the main monitor so something always shows).
- **Per-monitor settings are stored by monitor name** (`workspaceCountByMonitor`, `monitorPositions`), as a map in `Defaults.qml` with a `valid()` branch that clamps each entry. A name follows the monitor only as far as Hyprland names it, so a monitor moved to another port counts as a new one.
- **`config/` can't read `services/`**: when a config-level value needs the main monitor or the layout, define it in `Settings.qml` and let the service read it.
- **Hyprland's own state is per monitor too**: workspaces are bound to monitors by rules in the user's config (read by `services/WorkspaceRules.qml`, `monitorOf`), so with workspaces per monitor a bar only shows the ids that belong to its screen. A rule set with `hyprctl keyword` is wiped by a config reload (CLAUDE.md, Hyprland).

## Testing with two monitors

With the checkout shell running (`test-deploy` skill):

```sh
S=.claude/skills/test-deploy/scripts/shell.sh
hyprctl monitors | grep -E "^Monitor|focused"   # which is focused
$S layers                                        # each monitor's layer surfaces (the bar is "quickshell")
$S ipc <target> <function> [args]
$S errors
```

- Run the change with the focus on each monitor (`hyprctl dispatch focusmonitor <name>`), and with one monitor disabled or unplugged if the feature stores a monitor name.
- Compare `layers` before and after: a bar built or not shows as one surface more or less.
- You can't see the screens. Say what to look at on which monitor, and let the user look.
