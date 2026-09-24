pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Commands run when a notification arrives, by what it says: the rules made in
// the notification actions panel (modules/Notifications/NotificationActionsPanel),
// saved in config/NotificationActions.json. services/Notifications.qml runs
// the ones a new notification matches.
//
// A rule: { app, summary, body } - what the sending app's name, the title and
// the text are compared with ("" for anything), each with its `...Mode`:
// "contains", "starts" (starts with) or "is", all ignoring case; `command`, a
// command line run by sh, with the notification in $NOTIF_APP,
// $NOTIF_SUMMARY and $NOTIF_BODY (never pasted into the command itself, so
// no notification can inject anything into it); `silent`, true to keep it
// out of the pop-ups (it's still in the center); `enabled`.
Singleton {
  id: root

  readonly property var modes: ["contains", "starts", "is"]

  // The rules, each with every field there and valid.
  readonly property var rules: root.asArray(file.adapter.rules).map(rule => root.clean(rule))

  function asArray(list) {
    return list !== null && typeof list === "object" && typeof list.length === "number" ? Array.from(list) : []
  }

  // `rule` with anything missing or wrong put right: a new rule is clean({}).
  function clean(rule) {
    const text = value => typeof value === "string" ? value : ""
    const mode = (value, fallback) => root.modes.includes(value) ? value : fallback
    return {
      app: text(rule?.app),
      appMode: mode(rule?.appMode, "is"),
      summary: text(rule?.summary),
      summaryMode: mode(rule?.summaryMode, "contains"),
      body: text(rule?.body),
      bodyMode: mode(rule?.bodyMode, "contains"),
      command: text(rule?.command),
      silent: rule?.silent === true,
      enabled: rule?.enabled !== false
    }
  }

  // Whether `text` fits `pattern` the way `mode` says ("" fits anything).
  function fits(pattern, mode, text) {
    if (pattern === "") return true
    const value = String(text ?? "").toLowerCase()
    const wanted = pattern.toLowerCase()
    if (mode === "is") return value === wanted
    if (mode === "starts") return value.startsWith(wanted)
    return value.includes(wanted)
  }

  // The enabled rules with a command that a notification matches.
  function matching(notification) {
    return root.rules.filter(rule => rule.enabled && rule.command.trim() !== ""
      && root.fits(rule.app, rule.appMode, notification.appName)
      && root.fits(rule.summary, rule.summaryMode, notification.summary)
      && root.fits(rule.body, rule.bodyMode, notification.body))
  }

  // Runs a rule's command, the notification in its environment.
  function run(rule, notification) {
    Quickshell.execDetached({
      command: ["sh", "-c", rule.command],
      environment: {
        NOTIF_APP: notification.appName ?? "",
        NOTIF_SUMMARY: notification.summary ?? "",
        NOTIF_BODY: notification.body ?? ""
      }
    })
  }

  // Adds a rule (at the end), or replaces the one at `index`.
  function save(rule, index) {
    const list = root.rules.slice()
    if (index >= 0 && index < list.length) list[index] = root.clean(rule)
    else list.push(root.clean(rule))
    root.write(list)
  }

  function remove(index) {
    root.write(root.rules.filter((rule, i) => i !== index))
  }

  function setEnabled(index, on) {
    const list = root.rules.slice()
    if (!list[index]) return
    list[index] = Object.assign({}, list[index], { enabled: on })
    root.write(list)
  }

  function write(list) {
    file.adapter.rules = list
    file.writeAdapter()
  }

  FileView {
    id: file
    path: Paths.notificationActions
    blockLoading: true
    // The file only exists once a rule has been saved.
    printErrors: false
    // Edited by hand while the shell runs: picked up.
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      property var rules: []
    }
  }
}
