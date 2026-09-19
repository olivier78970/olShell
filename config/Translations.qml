pragma Singleton

import Quickshell

// The shell's texts, one dictionary per language, keyed like "power.logout".
// A value is a string, or for counts an object with `one` and `other`; "{0}",
// "{1}"... are replaced by the arguments given to I18n.tr(). To add a
// language: add a dictionary here with the same keys as `en`, and list its
// code in I18n.supported. A key missing from a language falls back to English.
Singleton {
  readonly property var en: ({
    // How this language writes things
    "format.locale": "en_US",
    "format.decimal": ".",
    "format.units": ["B", "KiB", "MiB", "GiB", "TiB", "PiB"],
    "format.dateTime": "dddd, MMMM d, yyyy HH:mm:ss",

    "common.cancel": "Cancel",
    "common.confirm": "Confirm",

    "clock.tab.agenda": "Agenda",
    "clock.tab.performance": "Performance",
    "agenda.today": "Today",
    "agenda.week": "W",

    "perf.cpu": "Processor",
    "perf.memory": "Memory",
    "perf.network": "Network",
    "perf.storage": "Storage",
    "perf.download": "Download",
    "perf.upload": "Upload",
    "perf.cores": { "one": "{0} core", "other": "{0} cores" },

    "cpu.core": "Core {0}",
    "ram.used": "{0} used / {1}",

    "launcher.search": "Search applications…",
    "launcher.noResults": "No results",
    "launcher.terminal": "terminal",

    "lock.caps": "Caps Lock",
    "lock.num": "Num Lock",
    "lock.on": "on",
    "lock.off": "off",

    "power.logout": "Log out",
    "power.restart": "Restart",
    "power.shutdown": "Shut down",
    "power.confirm.logout": "Log out?",
    "power.confirm.restart": "Restart the computer?",
    "power.confirm.shutdown": "Shut down the computer?",

    "carousel.apply": "Enter: apply",
    "wallpaper.title": "Wallpapers",
    "wallpaper.none": "No wallpaper found",
    "wallpaper.pod": "Picture of the day",

    "settings.title": "Settings",
    "settings.radius": "Widget radius",
    "settings.language": "Language",
    "settings.language.auto": "Automatic",
    "settings.opacity": "Widget opacity",
    "settings.spacing": "Widget spacing",
    "settings.barHeight": "Top bar height",
    "settings.barMarginTop": "Top bar top margin",
    "settings.barMarginLeft": "Top bar left margin",
    "settings.barMarginRight": "Top bar right margin",
    "settings.borderWidth": "Border width",
    "settings.reset": "Reset",
    "settings.hint": "↑ ↓ select  ·  ← → adjust (Shift: faster)  ·  Esc close",
    "theme.title": "Themes",
    "theme.auto": "Automatic",
    "theme.autoDescription": "Wallpaper colors",
    "theme.color.background": "Background",
    "theme.color.pill": "Pill",
    "theme.color.border": "Border",
    "theme.color.text": "Text",
    "theme.color.accent": "Accent"
  })

  readonly property var fr: ({
    "format.locale": "fr_FR",
    "format.decimal": ",",
    "format.units": ["o", "Kio", "Mio", "Gio", "Tio", "Pio"],
    "format.dateTime": "dddd d MMMM yyyy HH:mm:ss",

    "common.cancel": "Annuler",
    "common.confirm": "Confirmer",

    "clock.tab.agenda": "Agenda",
    "clock.tab.performance": "Performances",
    "agenda.today": "Aujourd'hui",
    "agenda.week": "S",

    "perf.cpu": "Processeur",
    "perf.memory": "Mémoire",
    "perf.network": "Réseau",
    "perf.storage": "Stockage",
    "perf.download": "Réception",
    "perf.upload": "Émission",
    "perf.cores": { "one": "{0} cœur", "other": "{0} cœurs" },

    "cpu.core": "Cœur {0}",
    "ram.used": "{0} utilisés / {1}",

    "launcher.search": "Rechercher une application…",
    "launcher.noResults": "Aucun résultat",
    "launcher.terminal": "terminal",

    "lock.caps": "Verrouillage majuscules",
    "lock.num": "Verrouillage numérique",
    "lock.on": "activé",
    "lock.off": "désactivé",

    "power.logout": "Déconnexion",
    "power.restart": "Redémarrer",
    "power.shutdown": "Éteindre",
    "power.confirm.logout": "Se déconnecter ?",
    "power.confirm.restart": "Redémarrer l'ordinateur ?",
    "power.confirm.shutdown": "Éteindre l'ordinateur ?",

    "carousel.apply": "Entrée : appliquer",
    "wallpaper.title": "Fonds d'écran",
    "wallpaper.none": "Aucun fond d'écran trouvé",
    "wallpaper.pod": "Image du jour",

    "settings.title": "Paramètres",
    "settings.radius": "Rayon des widgets",
    "settings.language": "Langue",
    "settings.language.auto": "Automatique",
    "settings.opacity": "Opacité des widgets",
    "settings.spacing": "Espacement des widgets",
    "settings.barHeight": "Hauteur de la barre",
    "settings.barMarginTop": "Marge haute de la barre",
    "settings.barMarginLeft": "Marge gauche de la barre",
    "settings.barMarginRight": "Marge droite de la barre",
    "settings.borderWidth": "Épaisseur des bordures",
    "settings.reset": "Réinitialiser",
    "settings.hint": "↑ ↓ choisir  ·  ← → régler (Maj : plus vite)  ·  Échap fermer",
    "theme.title": "Thèmes",
    "theme.auto": "Automatique",
    "theme.autoDescription": "Couleurs du fond d'écran",
    "theme.color.background": "Fond",
    "theme.color.pill": "Pilule",
    "theme.color.border": "Bordure",
    "theme.color.text": "Texte",
    "theme.color.accent": "Accent"
  })
}
