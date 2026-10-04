---
name: add-bar-widget
description: Add a new widget to olShell's bar (a button, an indicator, a gauge, a trigger opening a panel) and register it everywhere a widget id is listed - the Widgets file, BarWidgets, Settings.widgetIds, the default layout, the layout editor's icon, the IPC comment, translations and the README. Use it whenever the user wants something new on the bar, an icon or indicator for a feature, or a bar button for a panel, even if they don't say "widget".
---

# Adding a bar widget to olShell

A widget is listed by id in several places that don't reference each other. One that's missing from `Settings.widgetIds` is silently dropped from the layout. One without a layout-editor icon shows blank in the **Layout** tab. Copy a widget of the same shape:

- `ChatAiTrigger.qml`: an icon that opens a panel.
- `ZoomButton.qml`: an icon with a figure, a wheel action and a tooltip popup.
- `CpuUsage.qml`: a figure that can also be a ring gauge.
- `BluetoothButton.qml`: an icon with a menu.

## Decide first

- **Id** (camelCase, `chatAi`) and **component name** (`ChatAiTrigger` for a panel opener, `…Button` for an action, the thing's name for an indicator).
- **Default place**: a zone of the default layout (`barLeft` / `barCenter` / `barRight` in `Defaults.qml`, with or without a divider before it in `barDividers`), or off. Off by default suits an optional feature; the user turns it on in the **Layout** tab.
- **What it does**: open a panel (`<Name>State.toggle()`; a new panel is the `add-panel` skill), run an action through a service, show a popup or menu, or show a figure. Keep the system logic in a `services/` singleton, not in the widget.

## Writing the widget (`modules/Bar/Widgets/<Component>.qml`)

- A root `Item` with `anchors.verticalCenter: parent.verticalCenter` and `implicitWidth` / `implicitHeight` from its content, and a comment on top saying what it is and what clicking, the wheel or hovering does.
- **Left and right bars**: the bar can stand on a side edge, with the widgets stacked. Put an icon and a figure in a `BarStack` (side by side on a top bar, stacked on a side one), and give figures `sizeScale: Theme.barFigureScale`. Check `Theme.barVertical` for anything else that has to change.
- Draw text and icons with `BarText` (Nerd Font glyphs), so the font settings apply.
- A tooltip is a `HoverPopup` (call `hoverEntered()` / `hoverExited()` from the `MouseArea`) that starts with `PopupTitle { text: I18n.tr("settings.widget.<id>") }`, as every widget popup has a title. A menu is a `PopupMenu`.
- A figure that suits a gauge can offer a `<id>Ring` yes/no setting like `cpuRing` (`RingGauge` / `BarGauge`). Settings of the widget itself go on a tab of their own in **Bar widgets** (a `widget<Name>` page in `SettingsPages.categories`, its rows `category: "widget<Name>"`) through the `add-setting` skill.

## Registering it

1. `modules/Bar/BarWidgets.qml`: `<id>: <id>` in `components`, and `Component { id: <id>; <Component> {} }`.
2. `config/Settings.qml`: the id in `widgetIds`.
3. `config/Defaults.qml`: the id in its default zone and in `barDividers` if it gets a divider, or nowhere to start off.
4. `modules/Settings/BarLayoutEditor.qml`: its glyph in `icons`, the same one the bar draws.
5. `modules/Settings/SettingsModule.qml`: the id in the widget list of `place()`'s comment.
6. `config/Translations.qml`: `settings.widget.<id>` (its name in the layout editor and its popup title) and every text it shows, in en, fr and es.
7. `README.md` (search with `grep -n … | cut -c1-200`; its lines are very long):
   - the Structure tree's `Widgets/` lines;
   - the widget names in the **The bar's layout** paragraph;
   - the **Widgets** line of the From a script section;
   - a description of what it does, in its feature's section.

## Check

```sh
.claude/skills/add-bar-widget/scripts/check-widget.sh <id> <Component>   # e.g. chatAi ChatAiTrigger
.claude/scripts/check-translations.py
```

The widget checker also verifies that every id in `widgetIds` has its component and its layout-editor icon.

## Test

With the checkout shell running (see CLAUDE.md):

- `quickshell -p . ipc call settings place <id> right` puts it on the bar; `settings layout` shows where it is.
- `settings choose barPosition left`, then `top` again, to see it on a side bar.
- `settings widgetShown <id> 0` takes it off.
- Watch the log for QML errors, and tell the user what to look at (hover, click, popup).
