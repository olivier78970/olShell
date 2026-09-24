pragma Singleton

import Quickshell

// The built-in ("factory") value of every setting: what Settings.qml uses when
// nothing has been saved, and what the settings panel's Factory buttons put
// back. Nothing writes to this file; the user's own defaults, saved from the
// panel, are in UserDefaults.json (see Settings.qml).
Singleton {
  readonly property var values: ({
    radius: 5,
    opacity: 0.9,
    spacing: 15,
    barAutoHide: false,
    barAutoHideAnimated: true,
    barAutoHideDuration: 150,
    barAutoHideDelay: 500,
    barPosition: "top",
    barHeight: 40,
    barMarginTop: 5,
    barMarginBottom: 0,
    barMarginLeft: 5,
    barMarginRight: 5,
    panelGap: 0,
    workspaceCount: 5,
    barStyle: "widgets",
    borderWidth: 2,
    borderOpaque: false,
    blur: false,
    zoomBlocksInput: false,
    zoomMax: 8,
    zoomStep: 0.5,
    fontSize: 18,
    fontFamily: "0xProto Nerd Font",
    fontWeight: 400,
    fontLetterSpacing: 0,
    fontCaps: "none",
    fontItalic: false,
    fontUnderline: false,
    fontOutline: false,
    wallpaperTransition: "fade",
    wallpaperDuration: 2,
    screenshotMode: "screen",
    screenshotEdit: false,
    screenshotDir: Quickshell.env("HOME") + "/Pictures/Screenshots",
    notificationTimeout: 6,
    notificationMax: 4,
    notificationDnd: false,
    notificationPosition: "top-right",
    lockTimeout: 10,
    barCollapsed: [],
    barGroupsOff: [],
    barLeft: ["launcher", "settings", "workspaces", "activeWindow"],
    barCenter: ["clock", "wallpaper", "theme", "screenshot", "zoom"],
    barRight: ["tray", "cpu", "ram", "disk", "network", "volume", "notifications", "lock", "power"],
    barDividers: ["workspaces", "activeWindow", "wallpaper", "cpu", "ram", "disk", "network", "volume", "notifications", "lock"]
    })
}
