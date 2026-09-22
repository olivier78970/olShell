pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The look-and-feel values the user can adjust from the settings panel,
// saved in Settings.json. Theme reads them from here, so a change shows up
// everywhere at once. The language is handled by I18n.
Singleton {
  id: root

  // The built-in value of each setting (see Defaults.qml): what is used when
  // nothing has been saved, and to make up for a value that isn't valid.
  readonly property var defaults: Defaults.values

  // [minimum, maximum] of each setting, for the panel's sliders and to keep
  // a hand-edited file from breaking the layout.
  readonly property var limits: ({
    radius: [0, 30],
    opacity: [0, 1],
    spacing: [0, 40],
    barHeight: [28, 72],
    barMarginTop: [0, 100],
    barMarginBottom: [0, 100],
    barMarginLeft: [0, 300],
    barMarginRight: [0, 300],
    barOpacity: [0, 1],
    borderWidth: [0, 6],
    fontSize: [10, 32],
    fontWeight: [100, 900],
    fontLetterSpacing: [-2, 6],
    wallpaperDuration: [0.5, 10],
    notificationTimeout: [2, 30],
    notificationMax: [1, 8],
    lockTimeout: [0, 60]
  })

  // The values a setting can only take one of, in the order the panel lists
  // them. The wallpaper transitions are those of `awww img
  // --transition-type` ("simple" is left out: "fade" is the same, tunable, and
  // "none" already changes the wallpaper at once).
  readonly property var choices: ({
    barStyle: ["widgets", "full"],
    fontCaps: ["none", "upper", "lower", "small"],
    screenshotMode: ["screen", "region", "window"],
    notificationPosition: ["top-right", "top-center", "top-left", "center-right", "center-left", "bottom-right", "bottom-center", "bottom-left"],
    wallpaperTransition: ["fade", "none", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "outer", "any", "random"]
  })

  // Corner radius of every rounded item, in pixels.
  readonly property int radius: root.valid("radius", file.adapter.radius)
  // Opacity of pills, popups and panels (0 to 1).
  readonly property real opacity: root.valid("opacity", file.adapter.opacity)
  // Space between the widgets of a pill.
  readonly property int spacing: root.valid("spacing", file.adapter.spacing)
  readonly property int barHeight: root.valid("barHeight", file.adapter.barHeight)
  readonly property int barMarginTop: root.valid("barMarginTop", file.adapter.barMarginTop)
  // Extra room kept free below the bar, on top of the compositor's own gaps,
  // before the windows start.
  readonly property int barMarginBottom: root.valid("barMarginBottom", file.adapter.barMarginBottom)
  readonly property int barMarginLeft: root.valid("barMarginLeft", file.adapter.barMarginLeft)
  readonly property int barMarginRight: root.valid("barMarginRight", file.adapter.barMarginRight)
  // "widgets": the bar itself is transparent and each widget pill has its
  // own background (barOpacity has no effect). "full": the bar has one
  // continuous background and the pills' own backgrounds are transparent
  // (opacity has no effect on them).
  readonly property string barStyle: root.valid("barStyle", file.adapter.barStyle)
  // Opacity of the top bar's own background, used in the "full" barStyle.
  readonly property real barOpacity: root.valid("barOpacity", file.adapter.barOpacity)
  // Width of the outline around surfaces; 0 for none.
  readonly property int borderWidth: root.valid("borderWidth", file.adapter.borderWidth)
  // Text size in pixels, and the font of all text and icons (a font family
  // name; the icons are Nerd Font glyphs, so a Nerd Font is the safe choice).
  readonly property int fontSize: root.valid("fontSize", file.adapter.fontSize)
  readonly property string fontFamily: root.valid("fontFamily", file.adapter.fontFamily)
  // Text style, applied to all text (and the icons, which are text too): the
  // weight (100 thin to 900 black, 400 normal, 700 bold; a font without that
  // weight uses the nearest it has), the space added between letters in
  // pixels, one of choices.fontCaps (as typed / all upper case / all lower
  // case / small capitals), and italic, underline and outline switches.
  readonly property int fontWeight: root.valid("fontWeight", file.adapter.fontWeight)
  readonly property real fontLetterSpacing: root.valid("fontLetterSpacing", file.adapter.fontLetterSpacing)
  readonly property string fontCaps: root.valid("fontCaps", file.adapter.fontCaps)
  readonly property bool fontItalic: root.valid("fontItalic", file.adapter.fontItalic)
  readonly property bool fontUnderline: root.valid("fontUnderline", file.adapter.fontUnderline)
  readonly property bool fontOutline: root.valid("fontOutline", file.adapter.fontOutline)
  // The bar's widgets, by id, in the order the settings panel lists them (the
  // bar draws them from modules/Bar/BarWidgets.qml), and the three places on
  // the bar they can be put in. Every widget is in at most one of them.
  readonly property var widgetIds: ["launcher", "settings", "workspaces", "activeWindow", "clock", "wallpaper", "theme", "screenshot", "tray", "cpu", "ram", "disk", "network", "volume", "notifications", "lock", "power"]
  readonly property var zones: ["left", "center", "right"]
  // Where each widget is: { left: [ids], center: [ids], right: [ids] }, the
  // widgets of a zone in the order they are drawn. Made from the saved lists
  // with what is not a known widget, or is a second copy, left out; the
  // settings button is put back at the start of the left if it went missing,
  // so the panel stays reachable by clicking.
  readonly property var layout: root.buildLayout(file.adapter.barLeft, file.adapter.barCenter, file.adapter.barRight)
  // The widgets that have a divider drawn before them, when something is shown
  // before them in their pill. A divider goes with its widget when it moves.
  readonly property var dividers: root.valid("barDividers", file.adapter.barDividers)
  // A group is the widgets between two dividers (a widget starts one when it
  // is first in its pill or has a divider before it), and is named by the
  // widget that starts it. Each group is shown ("on"), shown only while the
  // pointer is over its pill ("hover") or never ("off"); these two lists have
  // the widgets that start the "hover" and the "off" groups (a group in neither
  // is "on"). Listing a widget that doesn't start a group (any more) does nothing.
  readonly property var groupModes: ["on", "hover", "off"]
  readonly property var collapsed: root.valid("barCollapsed", file.adapter.barCollapsed)
  readonly property var hiddenGroups: root.valid("barGroupsOff", file.adapter.barGroupsOff)
  // How awww changes from one wallpaper to the next (one of choices.wallpaperTransition),
  // and how long it takes, in seconds.
  readonly property string wallpaperTransition: root.valid("wallpaperTransition", file.adapter.wallpaperTransition)
  readonly property real wallpaperDuration: root.valid("wallpaperDuration", file.adapter.wallpaperDuration)
  // What the bar's screenshot widget captures: the focused screen, a rectangle or a window,
  // whether the picture is then opened in satty to be annotated, and the folder
  // pictures are saved in (an absolute path; a leading ~ is the home folder).
  readonly property string screenshotMode: root.valid("screenshotMode", file.adapter.screenshotMode)
  readonly property bool screenshotEdit: root.valid("screenshotEdit", file.adapter.screenshotEdit)
  readonly property string screenshotDir: root.valid("screenshotDir", file.adapter.screenshotDir)
  // Notifications: how long a pop-up stays on screen (in seconds, unless the
  // sender asks for another time; urgent ones stay until closed), how many
  // pop-ups are shown at once, and do-not-disturb, which keeps everything but
  // urgent notifications out of sight (they still go to the center).
  readonly property int notificationTimeout: root.valid("notificationTimeout", file.adapter.notificationTimeout)
  readonly property int notificationMax: root.valid("notificationMax", file.adapter.notificationMax)
  readonly property bool notificationDnd: root.valid("notificationDnd", file.adapter.notificationDnd)
  // Where the pop-ups appear on the screen (one of choices.notificationPosition).
  readonly property string notificationPosition: root.valid("notificationPosition", file.adapter.notificationPosition)
  // Minutes without input before the screen locks by itself (0: never).
  readonly property int lockTimeout: root.valid("lockTimeout", file.adapter.lockTimeout)

  // `value` for setting `key` kept within its limits (the default if it
  // isn't a number), and rounded to whole numbers except for the opacity
  // (hundredths), the duration and the letter spacing (tenths) and the weight
  // (hundreds). For a setting with a fixed list of
  // choices, `value` if it is one of them, else the default. The font family
  // is any non-empty name (whether it is installed isn't checked here), and a
  // yes/no setting is true or false.
  function valid(key, value) {
    // A list of widgets: only known ones (the layout also drops duplicates).
    if (Array.isArray(root.defaults[key])) {
      const list = root.asArray(value)
      return list.length > 0 || (value !== null && typeof value === "object") ? list.filter(id => root.widgetIds.includes(id)) : root.defaults[key]
    }
    if (key === "screenshotDir") {
      // ~ is the home folder, a trailing slash is dropped, and anything that
      // isn't then an absolute path (or is just "/") is the default.
      let path = typeof value === "string" ? value.trim() : ""
      const home = Quickshell.env("HOME")
      if (path === "~") path = home
      else if (path.startsWith("~/")) path = home + path.slice(1)
      path = path.replace(/\/+$/, "")
      return path.startsWith("/") ? path : root.defaults[key]
    }
    if (key === "fontFamily") return typeof value === "string" && value.length > 0 ? value : root.defaults[key]
    // A yes/no setting; a number counts too (0 is off), for the IPC calls.
    if (typeof root.defaults[key] === "boolean") {
      if (typeof value === "number" && !isNaN(value)) return value !== 0
      return typeof value === "boolean" ? value : root.defaults[key]
    }
    const choices = root.choices[key]
    if (choices !== undefined) return choices.includes(value) ? value : root.defaults[key]
    const [min, max] = root.limits[key]
    if (typeof value !== "number" || isNaN(value)) return root.defaults[key]
    const clamped = Math.max(min, Math.min(max, value))
    if (key === "opacity" || key === "barOpacity") return Math.round(clamped * 100) / 100
    if (key === "fontWeight") return Math.round(clamped / 100) * 100
    return key === "wallpaperDuration" || key === "fontLetterSpacing" ? Math.round(clamped * 10) / 10 : Math.round(clamped)
  }

  // `list` as a real array: a list read from the saved file is an array-like
  // object that Array.isArray refuses, and anything else gives an empty one.
  function asArray(list) {
    return list !== null && typeof list === "object" && typeof list.length === "number" ? Array.from(list) : []
  }

  function buildLayout(left, center, right) {
    const seen = new Set()
    const clean = list => root.asArray(list).filter(id => {
      if (!root.widgetIds.includes(id) || seen.has(id)) return false
      seen.add(id)
      return true
    })
    const zones = [clean(left), clean(center), clean(right)]
    if (!seen.has("settings")) zones[0].unshift("settings")
    return { left: zones[0], center: zones[1], right: zones[2] }
  }

  // The zone widget `id` is in ("left", "center" or "right"), or "off".
  function zoneOf(id) {
    return root.zones.find(zone => root.layout[zone].includes(id)) ?? "off"
  }

  // Puts widget `id` in `zone` ("left", "center", "right", or "off" to hide
  // it) at `position` (0 for first; the end if left out), taking it out of
  // where it was. The settings button can't be turned off.
  function place(id, zone, position) {
    if (!root.widgetIds.includes(id)) return
    if (zone === "off" && id === "settings") return
    if (zone !== "off" && !root.zones.includes(zone)) return
    // Where it was, for when it is turned on again.
    const from = root.zoneOf(id)
    if (zone === "off" && from !== "off") root.rememberPlace(id, from, root.layout[from].indexOf(id))
    const lists = {}
    for (const name of root.zones) lists[name] = root.layout[name].filter(other => other !== id)
    if (zone !== "off") {
      const index = position === undefined ? lists[zone].length : Math.max(0, Math.min(lists[zone].length, position))
      lists[zone].splice(index, 0, id)
    }
    root.set("barLeft", lists.left)
    root.set("barCenter", lists.center)
    root.set("barRight", lists.right)
  }

  // Where each widget that was turned off was, by id: { zone, position }.
  readonly property var lastPlace: file.adapter.barLastPlace ?? ({})

  // Forgets where the widgets that were turned off were.
  function forgetPlaces() {
    file.adapter.barLastPlace = ({})
    saveTimer.restart()
  }

  function rememberPlace(id, zone, position) {
    const places = {}
    for (const other in root.lastPlace) places[other] = root.lastPlace[other]
    places[id] = { zone: zone, position: position }
    file.adapter.barLastPlace = places
    saveTimer.restart()
  }

  // Shows widget `id` (back where it was, else in the zone it is in by default,
  // else at the end of the right one) or hides it (turns it off).
  function setWidgetShown(id, on) {
    if (!root.widgetIds.includes(id)) return
    if (!on) {
      root.place(id, "off")
      return
    }
    if (root.zoneOf(id) !== "off") return
    const last = root.lastPlace[id]
    const fallback = root.zones.find(zone => root.asArray(root.defaults["bar" + zone.charAt(0).toUpperCase() + zone.slice(1)]).includes(id)) ?? "right"
    if (last && root.zones.includes(last.zone)) root.place(id, last.zone, last.position)
    else root.place(id, fallback)
  }

  // Turns the divider before widget `id` on or off.
  function setDivider(id, on) {
    if (!root.widgetIds.includes(id)) return
    const others = root.dividers.filter(other => other !== id)
    root.set("barDividers", on ? others.concat([id]) : others)
  }

  // The groups of `zone`, in order, each the list of its widgets' ids.
  function groupsOf(zone) {
    const groups = []
    root.asArray(root.layout[zone]).forEach((id, index) => {
      if (index === 0 || root.dividers.includes(id)) groups.push([id])
      else groups[groups.length - 1].push(id)
    })
    return groups
  }

  // Whether the group `leader` starts is "on", "hover" or "off".
  function groupMode(leader) {
    if (root.hiddenGroups.includes(leader)) return "off"
    return root.collapsed.includes(leader) ? "hover" : "on"
  }

  // Turns the group `leader` starts on (shown) or off (never shown), keeping
  // whether it is shown on hover only for when it is on again.
  function setGroupShown(leader, on) {
    if (!root.widgetIds.includes(leader)) return
    const others = root.hiddenGroups.filter(id => id !== leader)
    root.set("barGroupsOff", on ? others : others.concat([leader]))
  }

  // Whether the group `leader` starts, when on, shows only on hover.
  function setGroupHover(leader, on) {
    if (!root.widgetIds.includes(leader)) return
    const others = root.collapsed.filter(id => id !== leader)
    root.set("barCollapsed", on ? others.concat([leader]) : others)
  }

  function setGroupMode(leader, mode) {
    if (!root.groupModes.includes(mode)) return
    root.setGroupShown(leader, mode !== "off")
    if (mode !== "off") root.setGroupHover(leader, mode === "hover")
  }

  // Moves the group `leader` starts `steps` places later (negative: earlier)
  // in its zone, past whole groups. Each group but the first has a divider
  // before it, so the dividers are set again for the new order.
  function moveGroup(leader, steps) {
    const zone = root.zoneOf(leader)
    if (zone === "off") return
    const groups = root.groupsOf(zone)
    const from = groups.findIndex(group => group[0] === leader)
    if (from < 0) return
    const to = Math.max(0, Math.min(groups.length - 1, from + steps))
    if (to === from) return
    groups.splice(to, 0, groups.splice(from, 1)[0])
    const ids = groups.reduce((all, group) => all.concat(group), [])
    root.set("bar" + zone.charAt(0).toUpperCase() + zone.slice(1), ids)
    root.set("barDividers", root.dividers.filter(id => !ids.includes(id)).concat(groups.slice(1).map(group => group[0])))
  }

  // Moves widget `id` `steps` places later (negative: earlier) within its zone.
  function move(id, steps) {
    const zone = root.zoneOf(id)
    if (zone === "off") return
    const index = root.layout[zone].indexOf(id)
    const target = Math.max(0, Math.min(root.layout[zone].length - 1, index + steps))
    if (target !== index) root.place(id, zone, target)
  }

  // The current value of setting `key`.
  function get(key) {
    return root[key]
  }

  // Changes a setting and saves it (shortly after the last change, so
  // dragging a slider doesn't write the file for every step).
  function set(key, value) {
    if (root.defaults[key] === undefined) return
    file.adapter[key] = root.valid(key, value)
    saveTimer.restart()
  }

  // The values the user saved as their own defaults, by setting key (in
  // UserDefaults.json, next to the built-in ones in Defaults.qml, which never
  // change): what Reset puts back. A setting missing from it has none.
  readonly property var userDefaults: userFile.adapter.values ?? ({})

  // Saves the current value of each of the settings `keys` as the user's own
  // default; `extra` ({ key: value }) adds values that aren't settings (the
  // language).
  function saveDefaults(keys, extra) {
    const values = {}
    for (const key in root.userDefaults) values[key] = root.userDefaults[key]
    for (const key of keys) {
      if (root.defaults[key] !== undefined) values[key] = root.valid(key, file.adapter[key])
    }
    Object.assign(values, extra ?? {})
    userFile.adapter.values = values
    userFile.writeAdapter()
  }

  // Puts each of the settings `keys` back to the user's own default
  // (`source` "mine"; the built-in one for a setting that has none) or to the
  // built-in one ("factory").
  function restoreDefaults(keys, source) {
    for (const key of keys) {
      if (root.defaults[key] === undefined) continue
      const saved = source === "mine" ? root.userDefaults[key] : undefined
      root.set(key, saved !== undefined ? saved : root.defaults[key])
    }
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: file.writeAdapter()
  }

  FileView {
    id: userFile
    path: Paths.userDefaults
    blockLoading: true
    // The file only exists once something has been saved.
    printErrors: false

    JsonAdapter {
      property var values: ({})
    }
  }

  FileView {
    id: file
    path: Paths.settings
    // Read synchronously so saved values are in place from the first frame.
    blockLoading: true

    JsonAdapter {
      property int radius: Defaults.values.radius
      property real opacity: Defaults.values.opacity
      property int spacing: Defaults.values.spacing
      property int barHeight: Defaults.values.barHeight
      property int barMarginTop: Defaults.values.barMarginTop
      property int barMarginBottom: Defaults.values.barMarginBottom
      property int barMarginLeft: Defaults.values.barMarginLeft
      property int barMarginRight: Defaults.values.barMarginRight
      property string barStyle: Defaults.values.barStyle
      property real barOpacity: Defaults.values.barOpacity
      property int borderWidth: Defaults.values.borderWidth
      property int fontSize: Defaults.values.fontSize
      property string fontFamily: Defaults.values.fontFamily
      property int fontWeight: Defaults.values.fontWeight
      property real fontLetterSpacing: Defaults.values.fontLetterSpacing
      property string fontCaps: Defaults.values.fontCaps
      property bool fontItalic: Defaults.values.fontItalic
      property bool fontUnderline: Defaults.values.fontUnderline
      property bool fontOutline: Defaults.values.fontOutline
      property string wallpaperTransition: Defaults.values.wallpaperTransition
      property real wallpaperDuration: Defaults.values.wallpaperDuration
      property string screenshotMode: Defaults.values.screenshotMode
      property bool screenshotEdit: Defaults.values.screenshotEdit
      property string screenshotDir: Defaults.values.screenshotDir
      property int notificationTimeout: Defaults.values.notificationTimeout
      property int notificationMax: Defaults.values.notificationMax
      property bool notificationDnd: Defaults.values.notificationDnd
      property string notificationPosition: Defaults.values.notificationPosition
      property int lockTimeout: Defaults.values.lockTimeout
      property var barCollapsed: Defaults.values.barCollapsed
      property var barGroupsOff: Defaults.values.barGroupsOff
      property var barLastPlace: ({})
      property var barLeft: Defaults.values.barLeft
      property var barCenter: Defaults.values.barCenter
      property var barRight: Defaults.values.barRight
      property var barDividers: Defaults.values.barDividers
    }
  }
}
