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
    curvedJoinsRadius: [0, 60],
    opacity: [0, 1],
    blurSize: [1, 20],
    blurPasses: [1, 8],
    blurNoise: [0, 0.2],
    blurContrast: [0, 2],
    blurBrightness: [0, 2],
    blurVibrancy: [0, 1],
    windowBorderWidth: [0, 10],
    windowRounding: [0, 30],
    windowGapsIn: [0, 40],
    windowGapsOut: [0, 80],
    windowActiveOpacity: [0.1, 1],
    windowInactiveOpacity: [0.1, 1],
    // Each app's own opacities in appOpacities (not a setting of its own).
    appOpacity: [0.1, 1],
    spacing: [0, 40],
    barHeight: [28, 72],
    animationDuration: [50, 600],
    hyprlandAnimationDuration: [0.25, 4],
    barAutoHideDelay: [0, 3000],
    barMarginTop: [0, 100],
    barMarginBottom: [0, 100],
    barMarginLeft: [0, 300],
    barMarginRight: [0, 300],
    panelGap: [0, 50],
    workspaceCount: [1, 20],
    borderWidth: [0, 6],
    fontSize: [10, 32],
    fontWeight: [100, 900],
    fontLetterSpacing: [-2, 6],
    wallpaperDuration: [0.5, 10],
    wallpaperSideCount: [1, 5],
    themeSideCount: [1, 5],
    notificationTimeout: [2, 30],
    notificationMax: [1, 8],
    lockTimeout: [0, 60],
    launcherResults: [3, 20],
    launcherHistory: [0, 10],
    chatAiHistory: [0, 200],
    switcherIconSize: [24, 96],
    switcherMaxShown: [3, 20],
    osdMargin: [0, 400],
    volumeOsdMargin: [0, 400],
    lockKeysOsdMargin: [0, 400],
    zoomMax: [2, 10],
    zoomStep: [0.1, 2],
    // matugen takes -1 to 1, but below 0 it turns the text a dim grey that is
    // hard to read on the background.
    matugenContrast: [0, 1],
    matugenLightness: [-1, 1]
  })

  // Where an OSD can be put on the screen: the vertical place, a dash, the
  // horizontal one.
  // How a picker's carousel can lay out its cards (see
  // components/CarouselCard.qml).
  readonly property var carouselStyles: ["coverflow", "gentle", "fan", "deck", "row"]
  readonly property var osdPositions: ["bottom-center", "bottom-left", "bottom-right", "center-center", "center-left", "center-right", "top-center", "top-left", "top-right"]

  // Where a full-screen panel opens: centered on the screen, or only
  // vertically against its left or right edge, attached to the bar at its
  // left end, in its middle or at its right end, or the same against the
  // screen's opposite edge.
  readonly property var panelPlacements: ["center", "center-left", "center-right", "bar-left", "bar-center", "bar-right", "opposite-left", "opposite-center", "opposite-right"]

  // The values a setting can only take one of, in the order the panel lists
  // them. The wallpaper transitions are those of `awww img
  // --transition-type` ("simple" is left out: "fade" is the same, tunable, and
  // "none" already changes the wallpaper at once). The matugen schemes are
  // those of `matugen image --type` (without the "scheme-" prefix), and the
  // sources are the colors of `--prefer`, plus "dominant" (the image's most
  // common color, `--source-color-index 0`). The accents and pill levels are
  // matugen's primary / secondary / tertiary colors and its
  // surface_container_* ones ("normal" is surface_container).
  readonly property var choices: ({
    barPosition: ["top", "bottom", "left", "right"],
    barStyle: ["widgets", "full"],
    cpuLayout: ["auto", "vertical", "horizontal"],
    ramLayout: ["auto", "vertical", "horizontal"],
    diskLayout: ["auto", "vertical", "horizontal"],
    volumeLayout: ["auto", "vertical", "horizontal"],
    networkLayout: ["auto", "vertical", "horizontal"],
    activeWindowLayout: ["auto", "vertical", "horizontal"],
    hyprlandWindowStyle: ["config", "popin", "slide", "gnomed"],
    hyprlandWorkspaceStyle: ["config", "slide", "slidevert", "fade", "slidefade", "slidefadevert"],
    launcherTab: ["all", "apps", "games", "files", "web", "webApps"],
    clockDate: ["long", "short", "numeric", "none"],
    fontCaps: ["none", "upper", "lower", "small"],
    screenshotMode: ["screen", "region", "window"],
    notificationPosition: ["top-right", "top-center", "top-left", "center-right", "center-left", "bottom-right", "bottom-center", "bottom-left"],
    osdPosition: root.osdPositions,
    volumeOsdPosition: root.osdPositions,
    lockKeysOsdPosition: root.osdPositions,
    panelPlacement: ["each"].concat(root.panelPlacements),
    launcherPlacement: root.panelPlacements,
    settingsPlacement: root.panelPlacements,
    shortcutsPlacement: root.panelPlacements,
    wallpaperPlacement: root.panelPlacements,
    themePlacement: root.panelPlacements,
    powerPlacement: root.panelPlacements,
    notificationActionsPlacement: root.panelPlacements,
    switcherPlacement: root.panelPlacements,
    clockPlacement: root.panelPlacements,
    notificationCenterPlacement: root.panelPlacements,
    chatAiPlacement: root.panelPlacements,
    switcherOrientation: ["vertical", "horizontal"],
    switcherScope: ["all", "workspace", "monitor"],
    weatherUnit: ["celsius", "fahrenheit"],
    wallpaperCarousel: root.carouselStyles,
    themeCarousel: root.carouselStyles,
    wallpaperTransition: ["fade", "none", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "outer", "any", "random"],
    matugenScheme: ["tonal-spot", "content", "fidelity", "vibrant", "expressive", "fruit-salad", "rainbow", "neutral", "monochrome"],
    matugenSource: ["saturation", "dominant", "less-saturation", "darkness", "lightness"],
    themeMode: ["dark", "light"],
    matugenAccent: ["primary", "secondary", "tertiary"],
    themePill: ["lowest", "low", "normal", "high", "highest"],
    themeAccent: ["default"].concat(ThemePresets.accentNames)
  })

  // The custom theme's colors, which only take a "#rrggbb" color.
  readonly property var colorKeys: ["customBackground", "customPill", "customBorder", "customText", "customAccent"]

  function validColor(value) {
    return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value.trim())
  }

  // Corner radius of every rounded item, in pixels.
  readonly property int radius: root.valid("radius", file.adapter.radius)
  // Opacity of pills, popups and panels (0 to 1).
  readonly property real opacity: root.valid("opacity", file.adapter.opacity)
  // Space between the widgets of a pill.
  readonly property int spacing: root.valid("spacing", file.adapter.spacing)
  // Whether the bar tucks itself away until the pointer reaches the edge of
  // the screen it's anchored to.
  readonly property bool barAutoHide: root.valid("barAutoHide", file.adapter.barAutoHide)
  // Whether the shell animates (the bar widgets' popups and the panels coming
  // and going, the auto-hiding bar sliding in and out), and how long one
  // animation takes, in ms.
  readonly property bool animations: root.valid("animations", file.adapter.animations)
  readonly property int animationDuration: root.valid("animationDuration", file.adapter.animationDuration)
  // Hyprland's animations, on top of its config's (see
  // services/HyprlandAnimations.qml): whether they run, how many times as
  // long as the config's they last (2: twice as long, 0.5: half), and the
  // style of the
  // windows' and the workspaces' (one of choices; "config" keeps the
  // config's).
  readonly property bool hyprlandAnimations: root.valid("hyprlandAnimations", file.adapter.hyprlandAnimations)
  readonly property real hyprlandAnimationDuration: root.valid("hyprlandAnimationDuration", file.adapter.hyprlandAnimationDuration)
  // Whether every Hyprland animation takes the shell's animation duration
  // instead (the multiplier above then has no effect).
  readonly property bool hyprlandAnimationSame: root.valid("hyprlandAnimationSame", file.adapter.hyprlandAnimationSame)
  readonly property string hyprlandWindowStyle: root.valid("hyprlandWindowStyle", file.adapter.hyprlandWindowStyle)
  readonly property string hyprlandWorkspaceStyle: root.valid("hyprlandWorkspaceStyle", file.adapter.hyprlandWorkspaceStyle)
  // How long, in milliseconds, the pointer has to be away from the bar (and
  // its margins) before it's tucked away again.
  readonly property int barAutoHideDelay: root.valid("barAutoHideDelay", file.adapter.barAutoHideDelay)
  // Which edge of the screen the bar is on. The top/bottom margins keep
  // their meaning either way: whichever is on the side the bar is anchored
  // to is the gap between the bar and that edge, and the other becomes
  // extra room kept free on the far side of the bar, before windows start.
  readonly property string barPosition: root.valid("barPosition", file.adapter.barPosition)
  readonly property int barHeight: root.valid("barHeight", file.adapter.barHeight)
  readonly property int barMarginTop: root.valid("barMarginTop", file.adapter.barMarginTop)
  readonly property int barMarginBottom: root.valid("barMarginBottom", file.adapter.barMarginBottom)
  readonly property int barMarginLeft: root.valid("barMarginLeft", file.adapter.barMarginLeft)
  readonly property int barMarginRight: root.valid("barMarginRight", file.adapter.barMarginRight)
  // Space between elements flush against each other: the bar and the panels
  // attached to it (the clock and notification panels, the wallpaper and theme
  // pickers), its widgets' menus and tooltips, and the notification pop-ups
  // under it; a submenu and its menu; and the pop-ups between themselves. 0 keeps them flush, their borders
  // overlapping (and lets them join with curves, see curvedJoins).
  readonly property int panelGap: root.valid("panelGap", file.adapter.panelGap)
  // Whether surfaces flush against each other join with concave corners
  // (see components/Fillet.qml): the panels attached to the bar and the
  // widgets' menus and tooltips curve out of it (in the "full" bar style),
  // and submenus into their menu - all only with no gap set and no border
  // (borderWidth 0; see Theme.curvedJoins).
  readonly property bool curvedJoins: root.valid("curvedJoins", file.adapter.curvedJoins)
  // The radius of those curves, in pixels, or with curvedJoinsRadiusSame the
  // widgets' own radius (see Theme.joinRadius).
  readonly property int curvedJoinsRadius: root.valid("curvedJoinsRadius", file.adapter.curvedJoinsRadius)
  readonly property bool curvedJoinsRadiusSame: root.valid("curvedJoinsRadiusSame", file.adapter.curvedJoinsRadiusSame)
  // How many workspace indicators the bar's workspaces widget shows (1 to
  // this number).
  readonly property int workspaceCount: root.valid("workspaceCount", file.adapter.workspaceCount)
  // Whether the bar shows as many as the Hyprland config sets up instead
  // (see services/WorkspaceRules.qml's shownCount).
  readonly property bool workspaceCountFromHyprland: root.valid("workspaceCountFromHyprland", file.adapter.workspaceCountFromHyprland)
  // "widgets": the bar itself is transparent and each widget pill has its
  // own background. "full": the bar has one continuous background instead
  // and the pills' own backgrounds are transparent. Either way, `opacity`
  // fades whichever background is actually drawn.
  readonly property string barStyle: root.valid("barStyle", file.adapter.barStyle)
  // Width of the outline around surfaces; 0 for none.
  readonly property int borderWidth: root.valid("borderWidth", file.adapter.borderWidth)
  // Whether that outline stays fully opaque instead of fading with the
  // widget opacity.
  readonly property bool borderOpaque: root.valid("borderOpaque", file.adapter.borderOpaque)
  // Whether Hyprland blurs what's behind every surface the widget opacity
  // can fade (the bar, pills, popups, panels, OSDs), see services/Blur.qml.
  readonly property bool blur: root.valid("blur", file.adapter.blur)
  // Hyprland's blur while it's on (its decoration.blur options, set live by
  // services/Blur.qml): its radius and number of passes, the noise, contrast,
  // brightness and vibrancy (color saturation) of what's blurred, and x-ray
  // (blur only the wallpaper behind, not the windows). They are global, so
  // they apply to transparent windows too, not just to the shell.
  readonly property int blurSize: root.valid("blurSize", file.adapter.blurSize)
  readonly property int blurPasses: root.valid("blurPasses", file.adapter.blurPasses)
  readonly property real blurNoise: root.valid("blurNoise", file.adapter.blurNoise)
  readonly property real blurContrast: root.valid("blurContrast", file.adapter.blurContrast)
  readonly property real blurBrightness: root.valid("blurBrightness", file.adapter.blurBrightness)
  readonly property real blurVibrancy: root.valid("blurVibrancy", file.adapter.blurVibrancy)
  readonly property bool blurXray: root.valid("blurXray", file.adapter.blurXray)
  // Hyprland's window look, which the shell always sets (see
  // services/HyprlandWindows.qml): the windows' border width and corner
  // radius (each its own, or with *Same the shell's border width and widget
  // radius), the gaps between windows (or the shell's panelGap) and around
  // them, and the opacity of the focused window and of the others.
  readonly property int windowBorderWidth: root.valid("windowBorderWidth", file.adapter.windowBorderWidth)
  readonly property bool windowBorderSame: root.valid("windowBorderSame", file.adapter.windowBorderSame)
  // Whether the windows' borders take the shell's colors (the focused one the
  // text color, the others the color of the shell's outlines), replacing the Hyprland config's.
  readonly property bool windowBorderColors: root.valid("windowBorderColors", file.adapter.windowBorderColors)
  readonly property int windowRounding: root.valid("windowRounding", file.adapter.windowRounding)
  readonly property bool windowRoundingSame: root.valid("windowRoundingSame", file.adapter.windowRoundingSame)
  readonly property int windowGapsIn: root.valid("windowGapsIn", file.adapter.windowGapsIn)
  readonly property bool windowGapsInSame: root.valid("windowGapsInSame", file.adapter.windowGapsInSame)
  readonly property int windowGapsOut: root.valid("windowGapsOut", file.adapter.windowGapsOut)
  readonly property real windowActiveOpacity: root.valid("windowActiveOpacity", file.adapter.windowActiveOpacity)
  readonly property real windowInactiveOpacity: root.valid("windowInactiveOpacity", file.adapter.windowInactiveOpacity)
  // Whether each follows the shell's opacity (`opacity`) instead.
  readonly property bool windowActiveOpacitySame: root.valid("windowActiveOpacitySame", file.adapter.windowActiveOpacitySame)
  readonly property bool windowInactiveOpacitySame: root.valid("windowInactiveOpacitySame", file.adapter.windowInactiveOpacitySame)
  // Apps with an opacity of their own, replacing the two above for their
  // windows: { class, active, inactive, activeSame, inactiveSame } each (the
  // class as Hyprland gives it, the opacities from 0.1 to 1, and whether each
  // follows the windows' general one instead).
  readonly property var appOpacities: root.valid("appOpacities", file.adapter.appOpacities)
  // Whether the screen zoom (services/Zoom.qml) is look-only: while zoomed,
  // the pointer, clicks and the wheel go to the shell instead of the apps
  // (the wheel zooms, a click or Escape zooms back out).
  readonly property bool zoomBlocksInput: root.valid("zoomBlocksInput", file.adapter.zoomBlocksInput)
  // How far the screen zoom goes, and how much one wheel notch (or one
  // zoomIn/zoomOut IPC call) changes it.
  readonly property int zoomMax: root.valid("zoomMax", file.adapter.zoomMax)
  readonly property real zoomStep: root.valid("zoomStep", file.adapter.zoomStep)
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
  readonly property var widgetIds: ["launcher", "settings", "workspaces", "activeWindow", "clock", "wallpaper", "theme", "screenshot", "zoom", "shortcuts", "tray", "cpu", "ram", "disk", "network", "connection", "bluetooth", "volume", "notifications", "lock", "power", "chatAi", "webApps"]
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
  // The widgets that are disabled: off the bar, and their feature (panel, service,
  // OSD, IPC calls) isn't loaded at all. The settings button can't be one.
  readonly property var disabledWidgets: root.valid("barDisabled", file.adapter.barDisabled).filter(id => id !== "settings")
  // How awww changes from one wallpaper to the next (one of choices.wallpaperTransition),
  // and how long it takes, in seconds.
  readonly property string wallpaperTransition: root.valid("wallpaperTransition", file.adapter.wallpaperTransition)
  readonly property real wallpaperDuration: root.valid("wallpaperDuration", file.adapter.wallpaperDuration)
  // How the wallpaper panel shows the wallpapers (one of
  // choices.wallpaperCarousel, see components/CarouselCard.qml), and how
  // many on each side of the selected one.
  readonly property string wallpaperCarousel: root.valid("wallpaperCarousel", file.adapter.wallpaperCarousel)
  readonly property int wallpaperSideCount: root.valid("wallpaperSideCount", file.adapter.wallpaperSideCount)
  // The same for the theme panel.
  readonly property string themeCarousel: root.valid("themeCarousel", file.adapter.themeCarousel)
  readonly property int themeSideCount: root.valid("themeSideCount", file.adapter.themeSideCount)
  // How matugen builds the "Automatique" palette from the wallpaper: the style
  // of the scheme (one of choices.matugenScheme) and which of the wallpaper's
  // colors it starts from (one of choices.matugenSource).
  readonly property string matugenScheme: root.valid("matugenScheme", file.adapter.matugenScheme)
  readonly property string matugenSource: root.valid("matugenSource", file.adapter.matugenSource)
  // How far matugen pushes the contrast between the "Automatique" colors, from
  // 0 (as designed) to 1 (the most).
  readonly property real matugenContrast: root.valid("matugenContrast", file.adapter.matugenContrast)
  // Whether the themes are dark or light (one of choices.themeMode): the
  // "Automatique" palette, and the fixed themes that have a light version.
  readonly property string themeMode: root.valid("themeMode", file.adapter.themeMode)
  // How much lighter (up to 1) or darker (down to -1) than designed the
  // "Automatique" background is (0 as designed; see services/Matugen.qml for
  // how far that goes in each mode).
  readonly property real matugenLightness: root.valid("matugenLightness", file.adapter.matugenLightness)
  // Which of the "Automatique" palette's colors the shell uses as its accent
  // (one of choices.matugenAccent). Only the shell: the other apps keep their
  // own use of the palette.
  readonly property string matugenAccent: root.valid("matugenAccent", file.adapter.matugenAccent)
  // How much the widgets' background stands out from the background, with
  // every theme (one of choices.themePill): for "Automatique" one of
  // matugen's surface colors, for the others their own, moved toward the
  // background or the text (see ThemePresets.withPillLevel).
  readonly property string themePill: root.valid("themePill", file.adapter.themePill)
  // The apps matugen colors along with the shell, with any theme (see
  // scripts/matugen-run.py). One turned off keeps the colors it last got.
  readonly property bool matugenHyprland: root.valid("matugenHyprland", file.adapter.matugenHyprland)
  readonly property bool matugenZen: root.valid("matugenZen", file.adapter.matugenZen)
  readonly property bool matugenAlacritty: root.valid("matugenAlacritty", file.adapter.matugenAlacritty)
  readonly property bool matugenGtk: root.valid("matugenGtk", file.adapter.matugenGtk)
  readonly property bool matugenQt: root.valid("matugenQt", file.adapter.matugenQt)
  readonly property bool matugenStarship: root.valid("matugenStarship", file.adapter.matugenStarship)
  // Apps added to those in the settings, each with a matugen template of its
  // own: [{ name, template (the template file), output (the file matugen
  // writes from it), hook (a shell command run after, or ""), on }]. One
  // without a template or an output is kept but not run.
  readonly property var matugenApps: root.valid("matugenApps", file.adapter.matugenApps)
  // The accent of the fixed themes, by the color it is (one of
  // choices.themeAccent; "default" is each theme's own, and so is a color the
  // theme doesn't have; see ThemePresets), and whether the other apps get
  // the exact colors of a fixed or custom theme rather than the palette
  // matugen builds around its accent.
  readonly property string themeAccent: root.valid("themeAccent", file.adapter.themeAccent)
  readonly property bool themeExactApps: root.valid("themeExactApps", file.adapter.themeExactApps)
  // The custom theme's five colors.
  readonly property string customBackground: root.valid("customBackground", file.adapter.customBackground)
  readonly property string customPill: root.valid("customPill", file.adapter.customPill)
  readonly property string customBorder: root.valid("customBorder", file.adapter.customBorder)
  readonly property string customText: root.valid("customText", file.adapter.customText)
  readonly property string customAccent: root.valid("customAccent", file.adapter.customAccent)
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
  // Where the volume OSD and the lock keys OSD appear on the screen (one of
  // osdPositions each), and how far from the edges they are, in pixels (from
  // the edge of the area the bar leaves free on its side).
  readonly property string volumeOsdPosition: root.valid("volumeOsdPosition", file.adapter.volumeOsdPosition)
  readonly property int volumeOsdMargin: root.valid("volumeOsdMargin", file.adapter.volumeOsdMargin)
  readonly property string lockKeysOsdPosition: root.valid("lockKeysOsdPosition", file.adapter.lockKeysOsdPosition)
  readonly property int lockKeysOsdMargin: root.valid("lockKeysOsdMargin", file.adapter.lockKeysOsdMargin)
  // The same for every OSD at once, and whether each OSD follows it (rather
  // than its own position and distance above).
  readonly property string osdPosition: root.valid("osdPosition", file.adapter.osdPosition)
  readonly property int osdMargin: root.valid("osdMargin", file.adapter.osdMargin)
  readonly property bool volumeOsdSame: root.valid("volumeOsdSame", file.adapter.volumeOsdSame)
  readonly property bool lockKeysOsdSame: root.valid("lockKeysOsdSame", file.adapter.lockKeysOsdSame)
  // Where each full-screen panel opens (one of panelPlacements each, see
  // components/ModalPanel.qml's `placement`).
  readonly property string launcherPlacement: root.valid("launcherPlacement", file.adapter.launcherPlacement)
  readonly property string settingsPlacement: root.valid("settingsPlacement", file.adapter.settingsPlacement)
  readonly property string shortcutsPlacement: root.valid("shortcutsPlacement", file.adapter.shortcutsPlacement)
  readonly property string wallpaperPlacement: root.valid("wallpaperPlacement", file.adapter.wallpaperPlacement)
  readonly property string themePlacement: root.valid("themePlacement", file.adapter.themePlacement)
  readonly property string powerPlacement: root.valid("powerPlacement", file.adapter.powerPlacement)
  readonly property string notificationActionsPlacement: root.valid("notificationActionsPlacement", file.adapter.notificationActionsPlacement)
  readonly property string switcherPlacement: root.valid("switcherPlacement", file.adapter.switcherPlacement)
  readonly property string clockPlacement: root.valid("clockPlacement", file.adapter.clockPlacement)
  readonly property string notificationCenterPlacement: root.valid("notificationCenterPlacement", file.adapter.notificationCenterPlacement)
  readonly property string chatAiPlacement: root.valid("chatAiPlacement", file.adapter.chatAiPlacement)
  // Whether the app switcher lists the windows in a column ("vertical") or
  // side by side ("horizontal", one of choices.switcherOrientation).
  readonly property string switcherOrientation: root.valid("switcherOrientation", file.adapter.switcherOrientation)
  // Which windows it lists (one of choices.switcherScope): all of them, those
  // of the focused workspace, or those of the focused monitor.
  readonly property string switcherScope: root.valid("switcherScope", file.adapter.switcherScope)
  // Whether it lists each app once (its windows gathered, the most recently
  // focused first) rather than each window.
  readonly property bool switcherGroupApps: root.valid("switcherGroupApps", file.adapter.switcherGroupApps)
  // What it shows with each window's icon (under it on a card, beside it in
  // a row): its title, and under it, a line each, its app and its workspace.
  readonly property bool switcherShowTitle: root.valid("switcherShowTitle", file.adapter.switcherShowTitle)
  readonly property bool switcherShowApp: root.valid("switcherShowApp", file.adapter.switcherShowApp)
  readonly property bool switcherShowWorkspace: root.valid("switcherShowWorkspace", file.adapter.switcherShowWorkspace)
  // The size of its icons, in pixels, and how many windows it shows at once
  // before scrolling.
  readonly property int switcherIconSize: root.valid("switcherIconSize", file.adapter.switcherIconSize)
  readonly property int switcherMaxShown: root.valid("switcherMaxShown", file.adapter.switcherMaxShown)
  // Whether releasing its shortcut's modifier switches to the selected
  // window; without it, Enter or a click does.
  readonly property bool switcherReleaseSwitch: root.valid("switcherReleaseSwitch", file.adapter.switcherReleaseSwitch)
  // Whether the horizontal cards show a live picture of each window instead
  // of its icon.
  readonly property bool switcherPreviews: root.valid("switcherPreviews", file.adapter.switcherPreviews)
  // Which tabs the clock panel shows (with none, its agenda still does).
  readonly property bool clockShowAgenda: root.valid("clockShowAgenda", file.adapter.clockShowAgenda)
  readonly property bool clockShowPerformance: root.valid("clockShowPerformance", file.adapter.clockShowPerformance)
  readonly property bool clockShowMedia: root.valid("clockShowMedia", file.adapter.clockShowMedia)
  readonly property bool clockShowWeather: root.valid("clockShowWeather", file.adapter.clockShowWeather)
  readonly property bool clockShowWorld: root.valid("clockShowWorld", file.adapter.clockShowWorld)
  // The places the clock panel's clocks tab shows the time of, in order:
  // [{ name, zone }], a name to show and an IANA time zone ("Asia/Tokyo").
  readonly property var worldClocks: root.valid("worldClocks", file.adapter.worldClocks)
  // The weather tab: its temperatures in Celsius or Fahrenheit (one of
  // choices.weatherUnit; the wind in km/h or mph with them), and the place
  // it's for, a name searched for (a town, "Lyon, France"...), or "" to find
  // it from the internet address.
  readonly property string weatherUnit: root.valid("weatherUnit", file.adapter.weatherUnit)
  readonly property string weatherLocation: root.valid("weatherLocation", file.adapter.weatherLocation)

  // The panels' placement settings, which panelPlacement sets all at once.
  readonly property var placementKeys: ["launcherPlacement", "settingsPlacement", "shortcutsPlacement", "wallpaperPlacement", "themePlacement", "powerPlacement", "notificationActionsPlacement", "switcherPlacement", "clockPlacement", "notificationCenterPlacement", "chatAiPlacement"]
  // Where every panel opens, when they all open in the same place, or
  // "each" when they don't. Not saved: setting it sets each of them (see
  // set()).
  readonly property string panelPlacement: {
    const placements = root.placementKeys.map(key => root[key])
    return placements.every(placement => placement === placements[0]) ? placements[0] : "each"
  }
  // Minutes without input before the screen locks by itself (0: never).
  readonly property int lockTimeout: root.valid("lockTimeout", file.adapter.lockTimeout)
  // Whether a fullscreen focused window (a game, a film) keeps the screen from
  // locking or blanking by itself.
  readonly property bool lockStayAwakeFullscreen: root.valid("lockStayAwakeFullscreen", file.adapter.lockStayAwakeFullscreen)
  // The launcher: the tab it opens on (one of choices.launcherTab), and how
  // many results its list is tall enough to show at once (more scroll).
  readonly property string launcherTab: root.valid("launcherTab", file.adapter.launcherTab)
  readonly property int launcherResults: root.valid("launcherResults", file.adapter.launcherResults)
  // How many of the applications last opened the launcher lists first with
  // an empty search (0: none).
  readonly property int launcherHistory: root.valid("launcherHistory", file.adapter.launcherHistory)
  // The bar clock: how it shows the date (one of choices.clockDate: the day
  // and month spelled out, abbreviated, in figures, or no date), and whether
  // the time has seconds (without them the clock only changes once a minute).
  readonly property string clockDate: root.valid("clockDate", file.adapter.clockDate)
  readonly property bool clockSeconds: root.valid("clockSeconds", file.adapter.clockSeconds)
  // How a widget lays itself out: "vertical" (the side-bar look: the CPU, RAM,
  // disk, volume and network speed as a ring around their icon with their
  // figures in their popup, the window title as its icon only with the title
  // on hover), "horizontal" (the top-bar look: figures beside the icon, icon
  // and title), or "auto" (the look of the bar's side: vertical on a left or
  // right bar, horizontal on a top or bottom one).
  readonly property string cpuLayout: root.valid("cpuLayout", file.adapter.cpuLayout)
  readonly property string ramLayout: root.valid("ramLayout", file.adapter.ramLayout)
  readonly property string diskLayout: root.valid("diskLayout", file.adapter.diskLayout)
  readonly property string volumeLayout: root.valid("volumeLayout", file.adapter.volumeLayout)
  readonly property string networkLayout: root.valid("networkLayout", file.adapter.networkLayout)
  readonly property string activeWindowLayout: root.valid("activeWindowLayout", file.adapter.activeWindowLayout)
  // The engines the launcher's web search offers, in order: each
  // { name, url, on } (%s in `url` is where the search goes), or
  // { browser: true, on } for the default browser's own default engine (see
  // services/WebSearch.qml), which is always in the list once. Those not `on`
  // are left out of the launcher.
  readonly property var launcherEngines: root.valid("launcherEngines", file.adapter.launcherEngines)
  // The web apps the bar's web apps widget opens, in order: each
  // { name, url, on }, a site opened with webAppCommand (see
  // services/WebApps.qml). Those not `on` are left out of the
  // widget's menu.
  readonly property var webApps: root.valid("webApps", file.adapter.webApps)
  // The command opening a web app: a program and its arguments, %s standing
  // for the app's address (added at the end when there is none). Run without
  // a shell (see services/WebApps.qml); empty puts the default back.
  readonly property string webAppCommand: root.valid("webAppCommand", file.adapter.webAppCommand)
  // What a click on a configurable bar widget runs (a program and its
  // arguments, empty for nothing), whether it runs in a terminal and whether
  // its window opens floating in the middle of the screen; see
  // services/WidgetActions.qml.
  readonly property string cpuAction: root.valid("cpuAction", file.adapter.cpuAction)
  readonly property bool cpuActionTerminal: root.valid("cpuActionTerminal", file.adapter.cpuActionTerminal)
  readonly property bool cpuActionFloating: root.valid("cpuActionFloating", file.adapter.cpuActionFloating)
  readonly property string ramAction: root.valid("ramAction", file.adapter.ramAction)
  readonly property bool ramActionTerminal: root.valid("ramActionTerminal", file.adapter.ramActionTerminal)
  readonly property bool ramActionFloating: root.valid("ramActionFloating", file.adapter.ramActionFloating)
  readonly property string diskAction: root.valid("diskAction", file.adapter.diskAction)
  readonly property bool diskActionTerminal: root.valid("diskActionTerminal", file.adapter.diskActionTerminal)
  readonly property bool diskActionFloating: root.valid("diskActionFloating", file.adapter.diskActionFloating)
  readonly property string networkAction: root.valid("networkAction", file.adapter.networkAction)
  readonly property bool networkActionTerminal: root.valid("networkActionTerminal", file.adapter.networkActionTerminal)
  readonly property bool networkActionFloating: root.valid("networkActionFloating", file.adapter.networkActionFloating)
  readonly property string connectionAction: root.valid("connectionAction", file.adapter.connectionAction)
  readonly property bool connectionActionTerminal: root.valid("connectionActionTerminal", file.adapter.connectionActionTerminal)
  readonly property bool connectionActionFloating: root.valid("connectionActionFloating", file.adapter.connectionActionFloating)
  readonly property string bluetoothAction: root.valid("bluetoothAction", file.adapter.bluetoothAction)
  readonly property bool bluetoothActionTerminal: root.valid("bluetoothActionTerminal", file.adapter.bluetoothActionTerminal)
  readonly property bool bluetoothActionFloating: root.valid("bluetoothActionFloating", file.adapter.bluetoothActionFloating)
  // The AI providers the chat AI panel can ask, in order: the built-in ones,
  // { builtin: "anthropic" | "openai" | "xai" | "google", model } (their address and API are
  // fixed, see services/ChatAi.qml), always in the list once, and those
  // added, { id, name, url, model }, OpenAI-compatible servers (`url` their
  // base address, ending with the version: https://api.mistral.ai/v1). `model`
  // is an id from the provider's own list, "" until one is picked. Their API
  // keys are in the secret keyring, under the built-in name or the `id`,
  // never here.
  readonly property var chatAiProviders: root.valid("chatAiProviders", file.adapter.chatAiProviders)
  readonly property var chatAiBuiltins: ["anthropic", "openai", "xai", "google"]

  // Whether `provider` is a valid added provider: an id, a name and a web
  // address.
  function validChatAiProvider(provider) {
    const text = field => typeof field === "string" && field.trim().length > 0
    return provider !== null && typeof provider === "object" && text(provider.id) && text(provider.name)
      && typeof provider.url === "string" && /^https?:\/\/\S+$/.test(provider.url.trim())
  }

  // Changes `fields` ({ model } of any provider, { name, url } of an added
  // one) of provider `index`. Returns false, changing nothing, when that
  // doesn't make a valid provider.
  function setChatAiProvider(index, fields) {
    const list = root.chatAiProviders.map(provider => Object.assign({}, provider))
    if (index < 0 || index >= list.length) return false
    const provider = Object.assign(list[index], fields)
    if (!provider.builtin && !root.validChatAiProvider(provider)) return false
    root.set("chatAiProviders", list)
    return true
  }

  // Adds an OpenAI-compatible provider at the end of the list; false if it
  // isn't valid.
  function addChatAiProvider(name, url) {
    const provider = { id: "custom-" + Date.now(), name: name, url: url, model: "" }
    if (!root.validChatAiProvider(provider)) return false
    root.set("chatAiProviders", root.chatAiProviders.concat([provider]))
    return true
  }

  // Takes added provider `index` out of the list; the built-in ones can't be.
  function removeChatAiProvider(index) {
    if (root.chatAiProviders[index] === undefined || root.chatAiProviders[index].builtin) return
    root.set("chatAiProviders", root.chatAiProviders.filter((provider, other) => other !== index))
  }
  // The tools the AI may use, each on or off: list a folder, find files by
  // name, search text in files, read a file, and with Anthropic, search the
  // web (each search billed by it) and read web pages (see
  // scripts/ai-ask.py).
  readonly property bool chatAiListDir: root.valid("chatAiListDir", file.adapter.chatAiListDir)
  readonly property bool chatAiFindFiles: root.valid("chatAiFindFiles", file.adapter.chatAiFindFiles)
  readonly property bool chatAiSearchText: root.valid("chatAiSearchText", file.adapter.chatAiSearchText)
  readonly property bool chatAiReadFile: root.valid("chatAiReadFile", file.adapter.chatAiReadFile)
  readonly property bool chatAiWebSearch: root.valid("chatAiWebSearch", file.adapter.chatAiWebSearch)
  readonly property bool chatAiWebFetch: root.valid("chatAiWebFetch", file.adapter.chatAiWebFetch)
  // What it may do with the shell itself: search and read its documentation
  // (README.md and docs/), and run its IPC calls, all but those that can't be undone
  // (see IPC_BLOCKED in scripts/ai-ask.py).
  readonly property bool chatAiShellDocs: root.valid("chatAiShellDocs", file.adapter.chatAiShellDocs)
  readonly property bool chatAiShellIpc: root.valid("chatAiShellIpc", file.adapter.chatAiShellIpc)
  // Folders it may read besides the home folder, and paths or file name
  // patterns ("*.sqlite") it may not, on top of the built-in secrets (see
  // scripts/ai-ask.py); both comma-separated, "" for none.
  readonly property string chatAiFolders: root.valid("chatAiFolders", file.adapter.chatAiFolders)
  readonly property string chatAiExclude: root.valid("chatAiExclude", file.adapter.chatAiExclude)
  // How many past questions the chat AI keeps for the question box's arrow
  // keys (0: none).
  readonly property int chatAiHistory: root.valid("chatAiHistory", file.adapter.chatAiHistory)
  // The chat AI provider asked when the panel opens (its id, see
  // services/ChatAi.qml), "" for the first one that can be asked. Its model
  // is the one set on its own row.
  readonly property string chatAiDefaultProvider: root.valid("chatAiDefaultProvider", file.adapter.chatAiDefaultProvider)
  // Whether the line along the bottom of the chat AI panel, saying what the
  // last question used, is shown.
  readonly property bool chatAiShowUsage: root.valid("chatAiShowUsage", file.adapter.chatAiShowUsage)
  // Whether the chat AI panel shows its hint (how it works, its keys) while it
  // is empty: before a first question, and after clearing it.
  readonly property bool chatAiShowHint: root.valid("chatAiShowHint", file.adapter.chatAiShowHint)
  // Whether the chat AI panel's title row shows the icons of the AI's access
  // options (its tools), on or off.
  readonly property bool chatAiShowAccess: root.valid("chatAiShowAccess", file.adapter.chatAiShowAccess)

  // Whether `name` and `url` make a search engine: a name, and a web address
  // with %s in it.
  function validEngine(name, url) {
    return typeof name === "string" && name.trim().length > 0
      && typeof url === "string" && /^https?:\/\/\S+$/.test(url.trim()) && url.includes("%s")
  }

  // Changes `fields` ({ name, url, on }, any of them) of engine `index`.
  // Returns false, changing nothing, when that doesn't make a valid engine.
  function setEngine(index, fields) {
    const list = root.launcherEngines.map(engine => Object.assign({}, engine))
    if (index < 0 || index >= list.length) return false
    const engine = Object.assign(list[index], fields)
    if (!engine.browser && !root.validEngine(engine.name, engine.url)) return false
    root.set("launcherEngines", list)
    return true
  }

  // Adds an engine at the end of the list (on); false if it isn't valid.
  function addEngine(name, url) {
    if (!root.validEngine(name, url)) return false
    root.set("launcherEngines", root.launcherEngines.concat([{ name: name, url: url, on: true }]))
    return true
  }

  // Whether `name` and `url` make a web app: a name, and a web address.
  function validWebApp(name, url) {
    return typeof name === "string" && name.trim().length > 0
      && typeof url === "string" && /^https?:\/\/\S+$/.test(url.trim())
  }

  // Changes `fields` ({ name, url, on }, any of them) of web app `index`.
  // Returns false, changing nothing, when that doesn't make a valid web app.
  function setWebApp(index, fields) {
    const list = root.webApps.map(app => Object.assign({}, app))
    if (index < 0 || index >= list.length) return false
    const app = Object.assign(list[index], fields)
    if (!root.validWebApp(app.name, app.url)) return false
    root.set("webApps", list)
    return true
  }

  // Adds a web app at the end of the list (on); false if it isn't valid.
  function addWebApp(name, url) {
    if (!root.validWebApp(name, url)) return false
    root.set("webApps", root.webApps.concat([{ name: name.trim(), url: url.trim(), on: true }]))
    return true
  }

  function removeWebApp(index) {
    root.set("webApps", root.webApps.filter((app, other) => other !== index))
  }

  // Moves web app `index` `steps` places later (negative: earlier).
  function moveWebApp(index, steps) {
    const list = root.webApps.slice()
    const target = Math.max(0, Math.min(list.length - 1, index + steps))
    if (index < 0 || index >= list.length || target === index) return
    list.splice(target, 0, list.splice(index, 1)[0])
    root.set("webApps", list)
  }

  // Changes `fields` ({ name, template, output, hook, on }, any of them) of
  // added app `index`. Returns false, changing nothing, when that leaves it
  // without a name.
  function setMatugenApp(index, fields) {
    const list = root.matugenApps.map(app => Object.assign({}, app))
    if (index < 0 || index >= list.length) return false
    const app = Object.assign(list[index], fields)
    if (typeof app.name !== "string" || app.name.trim().length === 0) return false
    root.set("matugenApps", list)
    return true
  }

  // Adds an app named `name`, on, with its files still to be set.
  function addMatugenApp(name) {
    root.set("matugenApps", root.matugenApps.concat([{ name: name, template: "", output: "", hook: "", on: true }]))
  }

  // Takes added app `index` out of the list.
  function removeMatugenApp(index) {
    root.set("matugenApps", root.matugenApps.filter((app, other) => other !== index))
  }

  // Changes `fields` ({ active, inactive, activeSame, inactiveSame }, any of
  // them) of app opacity `index`.
  function setAppOpacity(index, fields) {
    const list = root.appOpacities.map(app => Object.assign({}, app))
    if (index < 0 || index >= list.length) return
    Object.assign(list[index], fields)
    root.set("appOpacities", list)
  }

  // Gives the app of class `appClass` an opacity of its own, starting from the
  // windows' general ones (not twice the same app).
  function addAppOpacity(appClass) {
    if (typeof appClass !== "string" || appClass.length === 0 || root.appOpacities.some(app => app.class === appClass)) return
    root.set("appOpacities", root.appOpacities.concat([{ class: appClass, active: root.windowActiveOpacity, inactive: root.windowInactiveOpacity, activeSame: false, inactiveSame: false }]))
  }

  // Takes app opacity `index` out of the list: its windows go back to the
  // general opacities.
  function removeAppOpacity(index) {
    root.set("appOpacities", root.appOpacities.filter((app, other) => other !== index))
  }

  // Takes engine `index` out of the list; the browser's can't be.
  // Adds a place to the clocks tab (not twice the same).
  function addWorldClock(name, zone) {
    if (root.worldClocks.some(clock => clock.name === name && clock.zone === zone)) return
    root.set("worldClocks", root.worldClocks.concat([{ name: name, zone: zone }]))
  }

  function removeWorldClock(index) {
    root.set("worldClocks", root.worldClocks.filter((clock, other) => other !== index))
  }

  // Moves place `index` `steps` places later (negative: earlier).
  function moveWorldClock(index, steps) {
    const list = root.worldClocks.slice()
    const target = Math.max(0, Math.min(list.length - 1, index + steps))
    if (index < 0 || index >= list.length || target === index) return
    list.splice(target, 0, list.splice(index, 1)[0])
    root.set("worldClocks", list)
  }

  function removeEngine(index) {
    if (root.launcherEngines[index] === undefined || root.launcherEngines[index].browser) return
    root.set("launcherEngines", root.launcherEngines.filter((engine, other) => other !== index))
  }

  // Moves engine `index` `steps` places later (negative: earlier).
  function moveEngine(index, steps) {
    const list = root.launcherEngines.slice()
    const target = Math.max(0, Math.min(list.length - 1, index + steps))
    if (index < 0 || index >= list.length || target === index) return
    list.splice(target, 0, list.splice(index, 1)[0])
    root.set("launcherEngines", list)
  }

  // `value` for setting `key` kept within its limits (the default if it
  // isn't a number), and rounded to whole numbers except for the opacities
  // (hundredths), the blur's noise, contrast, brightness and vibrancy (ten
  // thousandths, as precise as Hyprland's own), the duration and the letter spacing (tenths) and the weight
  // (hundreds). For a setting with a fixed list of
  // choices, `value` if it is one of them, else the default. The font family
  // is any non-empty name (whether it is installed isn't checked here), and a
  // yes/no setting is true or false.
  function valid(key, value) {
    // The search engines: the valid ones, with the browser's once (put first
    // if it went missing).
    // The clocks tab's places: those with a name and a time zone's name.
    if (key === "worldClocks") {
      return root.asArray(value).filter(clock => clock !== null && typeof clock === "object"
          && typeof clock.name === "string" && clock.name.trim().length > 0
          && typeof clock.zone === "string" && /^[A-Za-z_]+(\/[A-Za-z0-9_+-]+)*$/.test(clock.zone))
        .map(clock => ({ name: clock.name.trim(), zone: clock.zone }))
    }
    if (key === "launcherEngines") {
      if (value === null || typeof value !== "object") return root.defaults[key]
      const list = []
      for (const engine of root.asArray(value)) {
        if (engine === null || typeof engine !== "object") continue
        const on = typeof engine.on === "boolean" ? engine.on : true
        if (engine.browser === true) {
          if (!list.some(other => other.browser)) list.push({ browser: true, on: on })
        } else if (root.validEngine(engine.name, engine.url)) {
          list.push({ name: engine.name.trim(), url: engine.url.trim(), on: on })
        }
      }
      if (!list.some(engine => engine.browser)) list.unshift({ browser: true, on: true })
      return list
    }
    // The web apps: those with a name and a web address.
    if (key === "webApps") {
      return root.asArray(value)
        .filter(app => app !== null && typeof app === "object" && root.validWebApp(app.name, app.url))
        .map(app => ({ name: app.name.trim(), url: app.url.trim(), on: typeof app.on === "boolean" ? app.on : true }))
    }
    // The added apps: those with a name, their other fields as text.
    // The app opacities: those with a class (once each), their opacities
    // within limits.appOpacity, on hundredths.
    // The chat AI's providers: the built-in ones once each (put back first
    // if missing), and the valid added ones, once each by id.
    if (key === "chatAiProviders") {
      if (value === null || typeof value !== "object") return root.defaults[key]
      const text = field => typeof field === "string" ? field.trim() : ""
      const list = []
      for (const provider of root.asArray(value)) {
        if (provider === null || typeof provider !== "object") continue
        if (root.chatAiBuiltins.includes(provider.builtin)) {
          if (!list.some(other => other.builtin === provider.builtin)) list.push({ builtin: provider.builtin, model: text(provider.model) })
        } else if (root.validChatAiProvider(provider) && !list.some(other => other.id === provider.id)) {
          list.push({ id: text(provider.id), name: text(provider.name), url: text(provider.url), model: text(provider.model) })
        }
      }
      // A built-in one missing (added since the file was written) comes after the
      // built-in ones there, before those added.
      const missing = root.chatAiBuiltins.filter(builtin => !list.some(other => other.builtin === builtin))
      return list.filter(provider => provider.builtin !== undefined)
        .concat(missing.map(builtin => ({ builtin: builtin, model: "" })))
        .concat(list.filter(provider => provider.builtin === undefined))
    }
    // The chat AI's added and excluded folders: text.
    if (key === "chatAiFolders" || key === "chatAiExclude") return typeof value === "string" ? value.trim().slice(0, 1000) : root.defaults[key]
    if (key === "appOpacities") {
      const [low, high] = root.limits.appOpacity
      const opacity = value => typeof value === "number" && !isNaN(value) ? Math.round(Math.max(low, Math.min(high, value)) * 100) / 100 : 1
      const seen = new Set()
      return root.asArray(value)
        .filter(app => app !== null && typeof app === "object" && typeof app.class === "string" && app.class.length > 0 && !seen.has(app.class) && seen.add(app.class))
        .map(app => ({ class: app.class, active: opacity(app.active), inactive: opacity(app.inactive), activeSame: app.activeSame === true, inactiveSame: app.inactiveSame === true }))
    }
    if (key === "matugenApps") {
      const text = field => typeof field === "string" ? field.trim() : ""
      return root.asArray(value)
        .filter(app => app !== null && typeof app === "object" && text(app.name).length > 0)
        .map(app => ({ name: text(app.name), template: text(app.template), output: text(app.output), hook: text(app.hook), on: typeof app.on === "boolean" ? app.on : true }))
    }
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
    // A provider's id, or "" for the first one that can be asked.
    if (key === "chatAiDefaultProvider") return typeof value === "string" ? value.trim().slice(0, 100) : root.defaults[key]
    // A place's name, or "" for none.
    if (key === "webAppCommand") return typeof value === "string" && value.trim().length > 0 ? value.trim().slice(0, 500) : root.defaults[key]
    // A widget's click action: a command, or "" for nothing.
    if (key.endsWith("Action") && typeof root.defaults[key] === "string") return typeof value === "string" ? value.trim().slice(0, 500) : root.defaults[key]
    if (key === "weatherLocation") return typeof value === "string" ? value.trim().slice(0, 100) : root.defaults[key]
    if (root.colorKeys.includes(key)) return root.validColor(value) ? value.trim().toLowerCase() : root.defaults[key]
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
    if (["opacity", "windowActiveOpacity", "windowInactiveOpacity", "hyprlandAnimationDuration"].includes(key)) return Math.round(clamped * 100) / 100
    if (["blurNoise", "blurContrast", "blurBrightness", "blurVibrancy"].includes(key)) return Math.round(clamped * 10000) / 10000
    if (key === "fontWeight") return Math.round(clamped / 100) * 100
    return key === "wallpaperDuration" || key === "fontLetterSpacing" || key === "zoomStep" || key === "matugenContrast" || key === "matugenLightness" ? Math.round(clamped * 10) / 10 : Math.round(clamped)
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
    // Putting a disabled widget on the bar enables it.
    if (zone !== "off" && !root.widgetEnabled(id)) root.set("barDisabled", root.disabledWidgets.filter(other => other !== id))
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

  // Whether widget `id` is enabled (not in the list of disabled ones).
  function widgetEnabled(id) {
    return !root.disabledWidgets.includes(id)
  }

  // Disables widget `id` (taking it off the bar, and unloading its feature) or
  // enables it again (back where it was on the bar). The settings button can't
  // be disabled.
  function setWidgetEnabled(id, on) {
    if (!root.widgetIds.includes(id) || id === "settings") return
    if (on) {
      if (root.widgetEnabled(id)) return
      root.set("barDisabled", root.disabledWidgets.filter(other => other !== id))
      root.setWidgetShown(id, true)
      return
    }
    root.place(id, "off")
    root.set("barDisabled", root.disabledWidgets.concat([id]).filter((other, index, all) => all.indexOf(other) === index))
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

  // The widget starting the group widget `id` is in (itself when it starts
  // one, or is off the bar).
  function leaderOf(id) {
    const zone = root.zoneOf(id)
    if (zone === "off") return id
    const group = root.groupsOf(zone).find(group => group.includes(id))
    return group ? group[0] : id
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

  // The groups of every zone with their modes, for the layout editor:
  // { left: [{ ids, mode }], center: [...], right: [...] }.
  function arrangement() {
    const zones = {}
    for (const zone of root.zones)
      zones[zone] = root.groupsOf(zone).map(ids => ({ ids: ids, mode: root.groupMode(ids[0]) }))
    return zones
  }

  // Makes the bar `zones` (as arrangement() gives them): the widgets of each
  // zone in the order of its groups, a divider before each group but the
  // first, and each group's mode under its first widget. A widget in none of
  // them is turned off (where it was is remembered, as with place()). Empty
  // groups are left out; `zones.disabled`, when given, lists the widgets to
  // disable (the others it doesn't place are only off); an arrangement without
  // the settings button is refused (false), so the panel stays reachable by clicking.
  function arrange(zones) {
    const lists = {}
    for (const zone of root.zones)
      lists[zone] = root.asArray(zones[zone]).filter(group => root.asArray(group.ids).length > 0)
    const placed = root.zones.reduce((all, zone) => all.concat(lists[zone].reduce((ids, group) => ids.concat(root.asArray(group.ids)), [])), [])
    if (!placed.includes("settings")) return false
    for (const id of root.widgetIds) {
      const from = root.zoneOf(id)
      if (!placed.includes(id) && from !== "off") root.rememberPlace(id, from, root.layout[from].indexOf(id))
    }
    const disabled = zones.disabled === undefined ? root.disabledWidgets : root.asArray(zones.disabled)
    root.set("barDisabled", disabled.filter(id => id !== "settings" && !placed.includes(id)))
    const leaders = [], hover = [], off = []
    for (const zone of root.zones) {
      lists[zone].forEach((group, index) => {
        const leader = group.ids[0]
        if (index > 0) leaders.push(leader)
        if (group.mode === "hover") hover.push(leader)
        if (group.mode === "off") off.push(leader)
      })
      root.set("bar" + zone.charAt(0).toUpperCase() + zone.slice(1), lists[zone].reduce((ids, group) => ids.concat(root.asArray(group.ids)), []))
    }
    root.set("barDividers", leaders)
    root.set("barCollapsed", hover)
    root.set("barGroupsOff", off)
    return true
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
    // A setting with no property of its own (the bar's layout lists) is read
    // from the file's adapter.
    return root[key] !== undefined ? root[key] : file.adapter[key]
  }

  // Changes a setting and saves it (shortly after the last change, so
  // dragging a slider doesn't write the file for every step).
  function set(key, value) {
    // Every panel's placement at once ("each" leaves them as they are).
    if (key === "panelPlacement") {
      if (root.panelPlacements.includes(value)) root.placementKeys.forEach(placementKey => root.set(placementKey, value))
      return
    }
    // An app to give an opacity of its own, by its class (the settings
    // panel's row adding one).
    if (key === "appOpacityAdd") {
      root.addAppOpacity(value)
      return
    }
    // A chat AI provider's model, by the provider's id (the settings panel's
    // model rows).
    if (typeof key === "string" && key.startsWith("chatAiModel:")) {
      const id = key.slice("chatAiModel:".length)
      const index = root.chatAiProviders.findIndex(provider => (provider.builtin ?? provider.id) === id)
      if (index >= 0 && typeof value === "string") root.setChatAiProvider(index, { model: value })
      return
    }
    if (root.defaults[key] === undefined) return
    // A color mistyped in the settings keeps the one there was.
    if (root.colorKeys.includes(key) && !root.validColor(value)) return
    file.adapter[key] = root.valid(key, value)
    saveTimer.restart()
  }

  Timer {
    id: saveTimer
    interval: 400
    onTriggered: file.writeAdapter()
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
      property bool barAutoHide: Defaults.values.barAutoHide
      property bool animations: Defaults.values.animations
      property int animationDuration: Defaults.values.animationDuration
      property bool hyprlandAnimations: Defaults.values.hyprlandAnimations
      property real hyprlandAnimationDuration: Defaults.values.hyprlandAnimationDuration
      property bool hyprlandAnimationSame: Defaults.values.hyprlandAnimationSame
      property string hyprlandWindowStyle: Defaults.values.hyprlandWindowStyle
      property string hyprlandWorkspaceStyle: Defaults.values.hyprlandWorkspaceStyle
      property int barAutoHideDelay: Defaults.values.barAutoHideDelay
      property string barPosition: Defaults.values.barPosition
      property int barHeight: Defaults.values.barHeight
      property int barMarginTop: Defaults.values.barMarginTop
      property int barMarginBottom: Defaults.values.barMarginBottom
      property int barMarginLeft: Defaults.values.barMarginLeft
      property int barMarginRight: Defaults.values.barMarginRight
      property int panelGap: Defaults.values.panelGap
      property bool curvedJoins: Defaults.values.curvedJoins
      property int curvedJoinsRadius: Defaults.values.curvedJoinsRadius
      property bool curvedJoinsRadiusSame: Defaults.values.curvedJoinsRadiusSame
      property int workspaceCount: Defaults.values.workspaceCount
      property bool workspaceCountFromHyprland: Defaults.values.workspaceCountFromHyprland
      property string barStyle: Defaults.values.barStyle
      property int borderWidth: Defaults.values.borderWidth
      property bool borderOpaque: Defaults.values.borderOpaque
      property bool blur: Defaults.values.blur
      property int blurSize: Defaults.values.blurSize
      property int blurPasses: Defaults.values.blurPasses
      property real blurNoise: Defaults.values.blurNoise
      property real blurContrast: Defaults.values.blurContrast
      property real blurBrightness: Defaults.values.blurBrightness
      property real blurVibrancy: Defaults.values.blurVibrancy
      property bool blurXray: Defaults.values.blurXray
      property int windowBorderWidth: Defaults.values.windowBorderWidth
      property bool windowBorderSame: Defaults.values.windowBorderSame
      property bool windowBorderColors: Defaults.values.windowBorderColors
      property int windowRounding: Defaults.values.windowRounding
      property bool windowRoundingSame: Defaults.values.windowRoundingSame
      property bool windowActiveOpacitySame: Defaults.values.windowActiveOpacitySame
      property bool windowInactiveOpacitySame: Defaults.values.windowInactiveOpacitySame
      property int windowGapsIn: Defaults.values.windowGapsIn
      property bool windowGapsInSame: Defaults.values.windowGapsInSame
      property int windowGapsOut: Defaults.values.windowGapsOut
      property real windowActiveOpacity: Defaults.values.windowActiveOpacity
      property real windowInactiveOpacity: Defaults.values.windowInactiveOpacity
      property var appOpacities: Defaults.values.appOpacities
      property bool zoomBlocksInput: Defaults.values.zoomBlocksInput
      property int zoomMax: Defaults.values.zoomMax
      property real zoomStep: Defaults.values.zoomStep
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
      property string wallpaperCarousel: Defaults.values.wallpaperCarousel
      property int wallpaperSideCount: Defaults.values.wallpaperSideCount
      property string themeCarousel: Defaults.values.themeCarousel
      property int themeSideCount: Defaults.values.themeSideCount
      property string matugenScheme: Defaults.values.matugenScheme
      property string matugenSource: Defaults.values.matugenSource
      property real matugenContrast: Defaults.values.matugenContrast
      property string themeMode: Defaults.values.themeMode
      property real matugenLightness: Defaults.values.matugenLightness
      property string matugenAccent: Defaults.values.matugenAccent
      property string themePill: Defaults.values.themePill
      property bool matugenHyprland: Defaults.values.matugenHyprland
      property bool matugenZen: Defaults.values.matugenZen
      property bool matugenAlacritty: Defaults.values.matugenAlacritty
      property bool matugenGtk: Defaults.values.matugenGtk
      property bool matugenQt: Defaults.values.matugenQt
      property bool matugenStarship: Defaults.values.matugenStarship
      property var matugenApps: Defaults.values.matugenApps
      property string themeAccent: Defaults.values.themeAccent
      property bool themeExactApps: Defaults.values.themeExactApps
      property string customBackground: Defaults.values.customBackground
      property string customPill: Defaults.values.customPill
      property string customBorder: Defaults.values.customBorder
      property string customText: Defaults.values.customText
      property string customAccent: Defaults.values.customAccent
      property string screenshotMode: Defaults.values.screenshotMode
      property bool screenshotEdit: Defaults.values.screenshotEdit
      property string screenshotDir: Defaults.values.screenshotDir
      property int notificationTimeout: Defaults.values.notificationTimeout
      property int notificationMax: Defaults.values.notificationMax
      property bool notificationDnd: Defaults.values.notificationDnd
      property string notificationPosition: Defaults.values.notificationPosition
      property string volumeOsdPosition: Defaults.values.volumeOsdPosition
      property int volumeOsdMargin: Defaults.values.volumeOsdMargin
      property string lockKeysOsdPosition: Defaults.values.lockKeysOsdPosition
      property int lockKeysOsdMargin: Defaults.values.lockKeysOsdMargin
      property string osdPosition: Defaults.values.osdPosition
      property int osdMargin: Defaults.values.osdMargin
      property bool volumeOsdSame: Defaults.values.volumeOsdSame
      property bool lockKeysOsdSame: Defaults.values.lockKeysOsdSame
      property int lockTimeout: Defaults.values.lockTimeout
      property bool lockStayAwakeFullscreen: Defaults.values.lockStayAwakeFullscreen
      property string launcherPlacement: Defaults.values.launcherPlacement
      property string settingsPlacement: Defaults.values.settingsPlacement
      property string shortcutsPlacement: Defaults.values.shortcutsPlacement
      property string wallpaperPlacement: Defaults.values.wallpaperPlacement
      property string themePlacement: Defaults.values.themePlacement
      property string powerPlacement: Defaults.values.powerPlacement
      property string notificationActionsPlacement: Defaults.values.notificationActionsPlacement
      property string switcherPlacement: Defaults.values.switcherPlacement
      property string clockPlacement: Defaults.values.clockPlacement
      property string notificationCenterPlacement: Defaults.values.notificationCenterPlacement
      property string chatAiPlacement: Defaults.values.chatAiPlacement
      property string switcherOrientation: Defaults.values.switcherOrientation
      property string switcherScope: Defaults.values.switcherScope
      property bool switcherGroupApps: Defaults.values.switcherGroupApps
      property bool switcherShowTitle: Defaults.values.switcherShowTitle
      property bool switcherShowApp: Defaults.values.switcherShowApp
      property bool switcherShowWorkspace: Defaults.values.switcherShowWorkspace
      property int switcherIconSize: Defaults.values.switcherIconSize
      property int switcherMaxShown: Defaults.values.switcherMaxShown
      property bool switcherReleaseSwitch: Defaults.values.switcherReleaseSwitch
      property bool switcherPreviews: Defaults.values.switcherPreviews
      property bool clockShowAgenda: Defaults.values.clockShowAgenda
      property bool clockShowPerformance: Defaults.values.clockShowPerformance
      property bool clockShowMedia: Defaults.values.clockShowMedia
      property bool clockShowWeather: Defaults.values.clockShowWeather
      property bool clockShowWorld: Defaults.values.clockShowWorld
      property var worldClocks: Defaults.values.worldClocks
      property string weatherUnit: Defaults.values.weatherUnit
      property string weatherLocation: Defaults.values.weatherLocation
      property string launcherTab: Defaults.values.launcherTab
      property string clockDate: Defaults.values.clockDate
      property bool clockSeconds: Defaults.values.clockSeconds
      property int launcherResults: Defaults.values.launcherResults
      property int launcherHistory: Defaults.values.launcherHistory
      property var launcherEngines: Defaults.values.launcherEngines
      property string cpuLayout: Defaults.values.cpuLayout
      property string ramLayout: Defaults.values.ramLayout
      property string diskLayout: Defaults.values.diskLayout
      property string volumeLayout: Defaults.values.volumeLayout
      property string networkLayout: Defaults.values.networkLayout
      property string activeWindowLayout: Defaults.values.activeWindowLayout
      property var webApps: Defaults.values.webApps
      property string webAppCommand: Defaults.values.webAppCommand
      property string cpuAction: Defaults.values.cpuAction
      property bool cpuActionTerminal: Defaults.values.cpuActionTerminal
      property bool cpuActionFloating: Defaults.values.cpuActionFloating
      property string ramAction: Defaults.values.ramAction
      property bool ramActionTerminal: Defaults.values.ramActionTerminal
      property bool ramActionFloating: Defaults.values.ramActionFloating
      property string diskAction: Defaults.values.diskAction
      property bool diskActionTerminal: Defaults.values.diskActionTerminal
      property bool diskActionFloating: Defaults.values.diskActionFloating
      property string networkAction: Defaults.values.networkAction
      property bool networkActionTerminal: Defaults.values.networkActionTerminal
      property bool networkActionFloating: Defaults.values.networkActionFloating
      property string connectionAction: Defaults.values.connectionAction
      property bool connectionActionTerminal: Defaults.values.connectionActionTerminal
      property bool connectionActionFloating: Defaults.values.connectionActionFloating
      property string bluetoothAction: Defaults.values.bluetoothAction
      property bool bluetoothActionTerminal: Defaults.values.bluetoothActionTerminal
      property bool bluetoothActionFloating: Defaults.values.bluetoothActionFloating
      property var chatAiProviders: Defaults.values.chatAiProviders
      property bool chatAiListDir: Defaults.values.chatAiListDir
      property bool chatAiFindFiles: Defaults.values.chatAiFindFiles
      property bool chatAiSearchText: Defaults.values.chatAiSearchText
      property bool chatAiReadFile: Defaults.values.chatAiReadFile
      property bool chatAiWebSearch: Defaults.values.chatAiWebSearch
      property bool chatAiWebFetch: Defaults.values.chatAiWebFetch
      property bool chatAiShellDocs: Defaults.values.chatAiShellDocs
      property bool chatAiShellIpc: Defaults.values.chatAiShellIpc
      property string chatAiFolders: Defaults.values.chatAiFolders
      property string chatAiExclude: Defaults.values.chatAiExclude
      property int chatAiHistory: Defaults.values.chatAiHistory
      property string chatAiDefaultProvider: Defaults.values.chatAiDefaultProvider
      property bool chatAiShowUsage: Defaults.values.chatAiShowUsage
      property bool chatAiShowHint: Defaults.values.chatAiShowHint
      property bool chatAiShowAccess: Defaults.values.chatAiShowAccess
      property var barCollapsed: Defaults.values.barCollapsed
      property var barGroupsOff: Defaults.values.barGroupsOff
      property var barDisabled: Defaults.values.barDisabled
      property var barLastPlace: ({})
      property var barLeft: Defaults.values.barLeft
      property var barCenter: Defaults.values.barCenter
      property var barRight: Defaults.values.barRight
      property var barDividers: Defaults.values.barDividers
    }
  }
}
