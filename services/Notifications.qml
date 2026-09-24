pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// The desktop notification server: it takes the place of mako, dunst or
// swaync (only one program can own the org.freedesktop.Notifications name).
// Every notification is an entry in `entries`, newest first, kept until it is
// dismissed or the sender closes it (in memory: they are gone when the shell
// restarts). Entries with `popup` set are shown as pop-ups by NotificationPopups;
// all of them are listed by NotificationCenter. A new notification can also run
// a command (config/NotificationActions.qml, set up in the notification
// actions panel: e.g. start the game launcher as the game controller
// connects). Also reachable from outside with:
//   quickshell -p . ipc call notifications toggle       # open or close the center
//   quickshell -p . ipc call notifications dnd 1        # do not disturb on (0: off)
//   quickshell -p . ipc call notifications toggleDnd
//   quickshell -p . ipc call notifications clear        # dismiss everything
//   quickshell -p . ipc call notifications count        # how many are in the center
Singleton {
  id: root

  // What the shell keeps about a notification, besides the notification itself.
  Component {
    id: entryComponent

    QtObject {
      required property Notification notification
      // Shown as a pop-up (until it times out or is closed).
      property bool popup: true
      readonly property date time: new Date()
    }
  }

  // The notifications, newest first: `entry.notification` is the
  // Quickshell Notification (appName, summary, body, actions...).
  property var entries: []
  readonly property bool dnd: Settings.notificationDnd
  // How many are in the center: it goes down only when one is dismissed.
  readonly property int count: root.entries.length
  // Whether one of them is urgent.
  readonly property bool urgent: root.entries.some(entry => root.isCritical(entry))
  // The pop-ups to show: none while do-not-disturb is on, except for urgent
  // notifications; at most Settings.notificationMax of them.
  readonly property var popups: root.entries
    .filter(entry => entry.popup && (!root.dnd || root.isCritical(entry)))
    .slice(0, Settings.notificationMax)
  // The entries by application, the one with the newest notification first:
  // [{ app, entries }].
  readonly property var groups: {
    const groups = []
    for (const entry of root.entries) {
      const app = entry.notification.appName
      const group = groups.find(group => group.app === app)
      if (group) group.entries.push(entry)
      else groups.push({ app: app, entries: [entry] })
    }
    return groups
  }
  // Where the pop-ups and the center are put (Settings.notificationPosition):
  // at the top or the bottom (neither: halfway down), and at the left or the
  // right (neither: in the middle).
  readonly property bool atTop: Settings.notificationPosition.startsWith("top")
  readonly property bool atBottom: Settings.notificationPosition.startsWith("bottom")
  readonly property bool atLeft: Settings.notificationPosition.endsWith("left")
  readonly property bool atRight: Settings.notificationPosition.endsWith("right")
  // Where they appear: the screen with the focus.
  readonly property var screen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

  function isCritical(entry) {
    return entry.notification.urgency === NotificationUrgency.Critical
  }

  function add(notification, popup) {
    const entry = entryComponent.createObject(root, { notification: notification, popup: popup })
    notification.closed.connect(() => root.remove(entry))
    root.entries = [entry].concat(root.entries)
  }

  function remove(entry) {
    if (!root.entries.includes(entry)) return
    root.entries = root.entries.filter(other => other !== entry)
    // Later, so what shows it can let go of it first.
    entry.destroy(1000)
  }

  // Closes a notification: it leaves the pop-ups and the center.
  function dismiss(entry) {
    entry.notification.dismiss()
    root.remove(entry)
  }

  function clear() {
    for (const entry of root.entries.slice()) root.dismiss(entry)
  }

  // Takes a notification off the screen but keeps it in the center. One
  // that says it is transient isn't kept.
  function hidePopup(entry) {
    if (entry.notification.transient) root.dismiss(entry)
    else entry.popup = false
  }

  // Runs the notification's default action, if it has one.
  function activate(entry) {
    const action = entry.notification.actions.find(action => action.identifier === "default")
    if (action) action.invoke()
    return action !== undefined
  }

  // The center was opened: it shows everything, so the pop-ups go away.
  function hideAllPopups() {
    for (const entry of root.entries) entry.popup = false
  }

  function setDnd(on) {
    Settings.set("notificationDnd", on)
  }

  NotificationServer {
    id: server

    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: notification => {
      notification.tracked = true
      const rules = NotificationActions.matching(notification)
      root.add(notification, !rules.some(rule => rule.silent))
      for (const rule of rules) NotificationActions.run(rule, notification)
    }

    Component.onCompleted: {
      // Notifications that outlived a reload of the shell: already seen.
      for (const notification of server.trackedNotifications.values) root.add(notification, false)
    }
  }

  IpcHandler {
    target: "notifications"

    function toggle(): void {
      NotificationCenterState.toggle()
    }

    function dnd(on: int): void {
      root.setDnd(on !== 0)
    }

    function toggleDnd(): void {
      root.setDnd(!root.dnd)
    }

    function clear(): void {
      root.clear()
    }

    function count(): int {
      return root.count
    }
  }
}
