pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The names, descriptions and keywords of installed applications in the
// shell's current language (I18n.language).
//
// Quickshell's own desktop entries are translated once, in the language of
// the process's environment. But every .desktop file carries all its
// translations (Comment[fr]=..., Comment[de]=...), so the ones for the
// supported languages are read straight from the files, and switching the
// shell's language switches the launcher's texts with it.
Singleton {
  id: root

  // Application id -> { Name: { tag: text }, GenericName: {...}, Comment: {...}, Keywords: {...} },
  // where tag is a language ("fr", "fr_FR") or "" for the untranslated
  // (English) text.
  property var entries: ({})

  // Reads the files again (also done every few minutes).
  function refresh() {
    scan.running = true
  }

  // The localized texts of application `id`, or null if its file wasn't
  // found: { name, genericName, comment, defaultName, keywords }. Each text
  // comes from the best translation available, in the order the desktop
  // entry spec gives: language_COUNTRY, then language, then untranslated.
  // `keywords` holds the translated and the untranslated ones.
  function info(id) {
    const raw = root.entries[id]
    if (!raw) return null

    const tags = [I18n.locale.name, I18n.language, ""]
    const pick = key => {
      const values = raw[key]
      if (!values) return undefined
      for (const tag of tags) {
        if (values[tag] !== undefined) return values[tag]
      }
      return undefined
    }
    const list = text => text ? text.split(";").map(item => item.trim()).filter(item => item.length > 0) : []

    return {
      name: pick("Name"),
      genericName: pick("GenericName"),
      comment: pick("Comment"),
      defaultName: raw.Name ? raw.Name[""] : undefined,
      keywords: Array.from(new Set(list(pick("Keywords")).concat(raw.Keywords ? list(raw.Keywords[""]) : [])))
    }
  }

  // The id of the application a .desktop file defines: its path under
  // .../applications/, without the extension, with "/" as "-".
  function idOf(path) {
    const marker = "/applications/"
    const start = path.lastIndexOf(marker)
    return path.slice(start + marker.length).replace(/\.desktop$/, "").replace(/\//g, "-")
  }

  // Parses "path<TAB>Key[tag]=value" lines. When several directories define
  // the same id the first one wins, as the directories come in priority order.
  function parse(text) {
    const result = {}
    const owner = {}
    for (const line of text.split("\n")) {
      const tab = line.indexOf("\t")
      if (tab < 0) continue
      const match = line.slice(tab + 1).match(/^([A-Za-z]+)(?:\[([^\]]*)\])?\s*=(.*)$/)
      if (!match) continue

      const path = line.slice(0, tab)
      const id = root.idOf(path)
      if (owner[id] === undefined) owner[id] = path
      if (owner[id] !== path) continue

      if (result[id] === undefined) result[id] = {}
      if (result[id][match[1]] === undefined) result[id][match[1]] = {}
      result[id][match[1]][match[2] ?? ""] = match[3]
    }
    return result
  }

  // Prints the Name / GenericName / Comment / Keywords lines of the
  // [Desktop Entry] group of every .desktop file (not those of its actions),
  // for the untranslated text and the supported languages only.
  Process {
    id: scan
    command: ["sh", "-c", `
      dirs="\${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      IFS=:
      for dir in $dirs; do
        [ -d "$dir/applications" ] && find "$dir/applications" -name '*.desktop'
      done | xargs -r awk -v langs="$1" '
        FNR == 1 { group = "" }
        /^\\[/ { group = $0; next }
        group == "[Desktop Entry]" && /^(Name|GenericName|Comment|Keywords)(\\[[^]]*\\])?[ \\t]*=/ {
          tag = ""
          if (match($0, /\\[[^]]*\\]/) && RSTART < index($0, "=")) tag = substr($0, RSTART + 1, RLENGTH - 2)
          if (tag == "" || tag ~ ("^(" langs ")([_@.].*)?$")) print FILENAME "\\t" $0
        }'
    `, "sh", I18n.supported.join("|")]

    stdout: StdioCollector {
      onStreamFinished: root.entries = root.parse(text)
    }
  }

  Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
