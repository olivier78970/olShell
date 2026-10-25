---
name: add-bar-widget
description: Add a new widget to olShell's bar (a button, an indicator, a gauge, a trigger opening a panel) and register it everywhere a widget id is listed - the Widgets file, BarWidgets, Settings.widgetIds, the default layout, the layout editor's icon, the IPC comment, translations and the README. Use it whenever the user wants something new on the bar, an icon or indicator for a feature, or a bar button for a panel, even if they don't say "widget".
---

# Adding a bar widget to olShell

A widget is listed by id in several places that don't reference each other. One that's missing from `Settings.widgetIds` is silently dropped from the layout. One without a layout-editor icon shows blank in the **Layout** tab. Copy a widget of the same shape:

- `ChatAiTrigger.qml`: an icon that opens a panel.
- `ZoomButton.qml`: an icon with a figure, a wheel action and a tooltip popup.
- `CpuUsage.qml`: a figure that can also be a ring gauge.
- `BluetoothButton.qml`: an icon with an action, a right-click menu and a tooltip.

## Decide first

- **Id** (camelCase, `chatAi`) and **component name** (`ChatAiTrigger` for a panel opener, `…Button` for an action, the thing's name for an indicator).
- **Default place**: a zone of the default layout (`barLeft` / `barCenter` / `barRight` in `Defaults.qml`, with or without a divider before it in `barDividers`), or off. Off by default suits an optional feature; the user turns it on in the **Layout** tab.
- **What it does**: open a panel (`<Name>State.toggle()`; a new panel is the `add-panel` skill), run an action through a service, show a popup or menu, or show a figure. Keep the system logic in a `services/` singleton, not in the widget.

## Writing the widget (`modules/Bar/Widgets/<Component>.qml`)

- A root `Item` with `anchors.verticalCenter: parent.verticalCenter` and `implicitWidth` / `implicitHeight` from its content, and a comment on top saying what it is and what clicking, the wheel or hovering does.
- **Left and right bars**: the bar can stand on a side edge, with the widgets stacked. Put an icon and a figure in a `BarStack` (side by side on a top bar, stacked on a side one), and give figures `sizeScale: Theme.barFigureScale`. Check `Theme.barVertical` for anything else that has to change.
- Draw text and icons with `BarText` (Nerd Font glyphs), so the font settings apply.
- A tooltip is a `HoverPopup` (call `hoverEntered()` / `hoverExited()` from the `MouseArea`) that starts with `PopupTitle { text: I18n.tr("settings.widget.<id>") }`, as every widget popup has a title. A menu is a `PopupMenu`.
- A figure that suits a gauge can offer a `<id>Layout` choice (auto / vertical / horizontal) like `cpuLayout` (`RingGauge` / `BarGauge`; the widget is a ring when it is `vertical`, or `auto` on a side bar). Settings of the widget itself go on a page of their own in **Bar widgets**' Widgets tab, where a dropdown picks the widget (a `widget<Name>` entry in `SettingsPages.widgetPages`, its rows `category: "widget<Name>"`) through the `add-setting` skill.

## Clicks and hover

Every widget answers the mouse the same way, so a user can guess what a widget does:

- **Left click**: the widget's action. It opens its application or panel, or does the one thing the widget is for (lock, switch the language, take a screenshot, focus a workspace). It never opens a menu.
- **Middle click** (optional): an alternative action, another application or panel (a `*State.toggle()`, `WidgetActions.run()`, `Quickshell.execDetached()`) or a quick toggle (the bell's do-not-disturb). It never opens a menu.
- **Right click** (optional): a `PopupMenu`, toggled with `menu.open = !menu.open`. The actions that aren't worth a click of their own go there. A left click closes it (`menu.open = false`) before running the action.
- **Hover** (optional): a `HoverPopup`, dismissed (`popup.dismiss()`) when a click runs the action or opens the menu.
- **Wheel** (optional): adjusts the widget's value (volume, zoom).
- `cursorShape: Qt.PointingHandCursor` only on a `MouseArea` that has an `onClicked` or `onWheel`.

Write the handler as `onClicked: mouse => { if (mouse.button === Qt.RightButton) … else … }` with `acceptedButtons` listing the buttons used (see `BluetoothButton.qml`): `check-clicks.py` reads that shape.

## A widget that fronts a feature can be disabled

A widget in the layout's **Disabled** lane (`Settings.widgetEnabled(id)` false) must take its whole feature with it: its panel, service, OSD and IPC calls are not loaded. `WidgetSlot` already doesn't load the widget. For the rest:

- an `IpcHandler` of the feature gets `enabled: Settings.widgetEnabled("<id>")` (a handler shared by several widgets is enabled while any of them is);
- a panel module's `LazyLoader` is `active: linger.active && Settings.widgetEnabled("<id>")`, one built in `shell.qml` sits in a `LazyLoader { active: Settings.widgetEnabled("<id>") }`;
- a panel the widget opens goes in `Panels.widgetPanels` (config/Panels.qml), which refuses to open it and closes it when disabled;
- a service that applies an effect (as zoom does) puts it back when disabled.

A widget with no feature of its own (the tray, workspaces) needs none of this. The README's list of what each widget takes with it is in docs/settings.md (**Disabled**).

## Registering it

1. `modules/Bar/BarWidgets.qml`: `<id>: <id>` in `components`, and `Component { id: <id>; <Component> {} }`.
2. `config/Settings.qml`: the id in `widgetIds`.
3. `config/Defaults.qml`: the id in its default zone and in `barDividers` if it gets a divider, or nowhere to start off.
4. `modules/Settings/BarLayoutEditor.qml`: its glyph in `icons`, the same one the bar draws.
5. `modules/Settings/SettingsModule.qml`: the id in the widget list of `place()`'s comment.
6. `config/Translations.qml` (add keys with `.claude/scripts/add-translation.py <key> "<en>" "<fr>" "<es>" [--after <key>]`): `settings.widget.<id>` (its name in the layout editor and its popup title) and every text it shows, in en, fr and es.
7. Docs (search `docs/*.md` with `grep -n … | cut -c1-200`; its lines are very long):
   - run `.claude/scripts/structure.py` (it lists the widget from its header comment, which you write);
   - the widget names in the **The bar's layout** paragraph of `docs/settings.md`;
   - a description of what it does, in its feature's section.

## Check

```sh
.claude/skills/add-bar-widget/scripts/check-widget.sh <id> <Component>   # e.g. chatAi ChatAiTrigger
.claude/scripts/check-translations.py
```

The widget checker also verifies that every id in `widgetIds` has its component and its layout-editor icon, and runs `check-clicks.py <Component>` (the click rules above; with no argument it checks every widget, as `check-all.sh` does).

## Test

With the checkout shell running (see CLAUDE.md):

- `quickshell -p . ipc call settings place <id> right` puts it on the bar; `settings layout` shows where it is.
- `settings choose barPosition left`, then `top` again, to see it on a side bar.
- `settings widgetShown <id> 0` takes it off.
- Watch the log for QML errors, and tell the user what to look at (hover, click, popup).
