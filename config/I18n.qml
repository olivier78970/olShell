pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Localization: which language the shell speaks, and how to look up and
// format texts in it (see Translations.qml for the texts).
//
// The language is "auto" (follow the system's, English if it isn't
// supported), or a fixed one chosen with select() / the bar's language
// button / `quickshell -p . ipc call language set fr`. The choice is
// remembered in LocaleState.json. tr() reads `language`, so anything bound
// to it updates as soon as the language changes.
Singleton {
  id: root

  readonly property var supported: ["en", "fr"]
  readonly property string fallback: "en"

  // "auto" or one of `supported`, as chosen by the user.
  readonly property string setting: file.adapter.setting
  // The language actually in use: one of `supported`.
  readonly property string language: root.setting === "auto" ? root.systemLanguage() : root.setting
  readonly property var locale: Qt.locale(root.value("format.locale") ?? "en_US")

  // The system's language, as far as we support it.
  function systemLanguage() {
    const raw = (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").toLowerCase()
    const code = raw.slice(0, 2)
    return root.supported.includes(code) ? code : root.fallback
  }

  // Makes `setting` ("auto" or a supported language) the choice, and saves it.
  function select(setting) {
    if (setting !== "auto" && !root.supported.includes(setting)) return false
    file.adapter.setting = setting
    file.writeAdapter()
    return true
  }

  // Switches between the two supported languages (from whichever is in use).
  function toggle() {
    const index = root.supported.indexOf(root.language)
    root.select(root.supported[(index + 1) % root.supported.length])
  }

  // The raw entry for `key` in the current language, else in the fallback
  // language, else undefined.
  function value(key) {
    const own = Translations[root.language]
    if (own && own[key] !== undefined) return own[key]
    return Translations[root.fallback][key]
  }

  // The text for `key`, with "{0}", "{1}"... replaced by the arguments. If the
  // entry has `one` / `other` forms, the first argument is the count that
  // picks between them (in French, 0 counts as singular).
  function tr(key, ...args) {
    let entry = root.value(key)
    if (entry === undefined) return key
    if (typeof entry === "object" && entry.other !== undefined) {
      const count = Number(args[0])
      const singular = root.language === "fr" ? count < 2 : count === 1
      entry = singular ? entry.one : entry.other
    }
    return String(entry).replace(/\{(\d+)\}/g, (match, index) => args[Number(index)] ?? match)
  }

  // A number with the language's decimal separator.
  function formatNumber(number, digits) {
    return number.toFixed(digits).replace(".", root.value("format.decimal"))
  }

  IpcHandler {
    target: "language"

    // set auto | en | fr
    function set(language: string): void {
      root.select(language)
    }

    function toggle(): void {
      root.toggle()
    }

    function get(): string {
      return root.language
    }
  }

  FileView {
    id: file
    path: Paths.localeState
    // Read synchronously so the saved language is in place from the first
    // frame instead of flashing the system's and then switching.
    blockLoading: true

    JsonAdapter {
      property string setting: "auto"
    }
  }
}
