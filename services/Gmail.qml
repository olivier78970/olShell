pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Watches the Gmail inbox of Settings.gmailAddress (scripts/gmail.py, over
// IMAP IDLE with an app password kept in the keyring): each new mail is
// notified, with buttons opening it in Gmail and marking it as read, and the
// unread count is what the gmail bar widget shows. It runs while
// Settings.gmailEnabled is on, an address is set, the gmail widget isn't
// disabled and the keyring has the password. IPC: `gmail check` connects
// again now, `gmail open` opens the inbox, `gmail unread` prints the count
// (-1 when unknown), `gmail openMail <link>` is a notification's Open (the
// widget's click action, else the link in the browser), `gmail status` says what the watching is at, `gmail
// forgetPassword` takes the password out of the keyring.
Singleton {
  id: root

  // Whether the inbox is wanted watched (the password aside).
  readonly property bool active: Settings.gmailEnabled && Settings.gmailAddress !== "" && Settings.widgetEnabled("gmail")
  readonly property string address: Settings.gmailAddress

  // Whether the keyring has the address's app password (false until known).
  property bool hasPassword: false
  // The inbox's unread conversations (as Gmail counts them), or -1 until the
  // watcher says.
  property int unread: -1
  // What stops the watcher: "" (nothing), "password" (none in the keyring),
  // "appPassword" (the account's own password was typed, not an app
  // password), "login" (Gmail refused the address or the password) or "network" (it
  // connects again on its own).
  property string error: ""
  // What the last change of the password gave: "" (nothing to say), or the
  // keyring's error message.
  property string passwordError: ""

  // The inbox in Gmail's web page, for the account by its address: Gmail
  // signs in to it, or switches to it among the accounts signed in (the
  // /mail/u/<address>/ form is a 404 while that account isn't signed in).
  readonly property string inboxLink: "https://mail.google.com/mail/?authuser=" + encodeURIComponent(root.address) + "#inbox"

  onActiveChanged: root.restart()
  onAddressChanged: {
    root.hasPassword = false
    root.lookUpPassword()
  }
  Component.onCompleted: root.lookUpPassword()

  // Starts the watcher again from scratch, or stops it when not wanted.
  function restart() {
    retry.stop()
    watcher.running = false
    root.unread = -1
    if (!root.active) {
      root.error = ""
      return
    }
    if (!root.hasPassword) {
      root.error = "password"
      return
    }
    root.error = ""
    // (Started on the next turn, once the old one is stopped.)
    Qt.callLater(() => watcher.running = root.active && root.hasPassword)
  }

  // What a click on the widget does: runs its action (Settings.gmailAction,
  // a command or a web app), else opens the inbox in the browser.
  function openApp() {
    if (!WidgetActions.run("gmail")) root.openInbox()
  }

  // Opens the inbox in the browser.
  function openInbox() {
    Qt.openUrlExternally(root.inboxLink)
  }

  // Checks whether the keyring has the address's password, then restarts.
  function lookUpPassword() {
    if (root.address === "") {
      root.restart()
      return
    }
    root.run(["password", "has", root.address], null, text => {
      root.hasPassword = root.parse(text)?.has === true
      root.restart()
    })
  }

  // Puts the app password in the keyring (spaces don't count), or takes it
  // out when `password` is empty, then restarts the watcher with it. The
  // password goes to the script through its standard input, never on its
  // command line.
  function setPassword(password) {
    if (root.address === "") return
    const trimmed = (password ?? "").trim()
    root.passwordError = ""
    root.run(["password", trimmed === "" ? "clear" : "set", root.address], trimmed === "" ? null : trimmed, text => {
      const answer = root.parse(text)
      if (answer?.ok !== true) root.passwordError = answer?.message || "?"
      root.lookUpPassword()
    })
  }

  // A JSON line printed by the script, or null.
  function parse(text) {
    try {
      return JSON.parse(text)
    } catch (error) {
      return null
    }
  }

  // Shows a new mail's notification (or one for several mails at once). It
  // waits for its buttons, so it runs on its own.
  function notify(uid, link, title, body) {
    Quickshell.execDetached(["python3", Paths.gmailScript, "notify", root.address, uid, link, title, body,
      I18n.tr("gmail.open"), I18n.tr("gmail.markRead"), Paths.shellDir])
  }

  Process {
    id: watcher
    command: ["python3", Paths.gmailScript, "watch", root.address]

    stdout: SplitParser {
      onRead: line => {
        const message = root.parse(line)
        if (!message) return
        if (message.event === "unread") {
          root.unread = message.count
          root.error = ""
        } else if (message.event === "mail") {
          root.notify(String(message.uid), message.link, message.from || root.address, message.subject || I18n.tr("gmail.noSubject"))
        } else if (message.event === "mails") {
          root.notify("", root.inboxLink, I18n.tr("gmail.newMails", message.count), root.address)
        } else if (message.event === "error") {
          root.error = message.reason
          if (message.reason === "password") root.hasPassword = false
        }
      }
    }

    // A refused password waits for another one; anything else unexpected
    // (not the watcher stopped by restart(), which kills it) is tried again a
    // little later.
    onExited: (code, status) => {
      if (status === Process.NormalExit && code !== 2 && root.active && root.hasPassword) retry.start()
    }
  }

  // Waits before starting a watcher that stopped on its own.
  Timer {
    id: retry
    interval: 30000
    onTriggered: root.restart()
  }

  // The keyring jobs waiting their turn ({ args, input, done }): one runs at
  // a time, `input` written to its standard input (null for none), `done`
  // given what it printed.
  property var queue: []

  function run(args, input, done) {
    root.queue.push({ args: args, input: input, done: done })
    root.next()
  }

  function next() {
    if (helper.running || helper.job !== null || root.queue.length === 0) return
    const job = root.queue.shift()
    helper.job = job
    helper.command = ["python3", Paths.gmailScript].concat(job.args)
    helper.stdinEnabled = job.input !== null
    helper.running = true
  }

  Process {
    id: helper

    // The job running, until what it printed has been handed over.
    property var job: null

    onStarted: {
      if (helper.job.input === null) return
      helper.write(helper.job.input)
      // Closes its standard input, so the script reads the password to its end.
      helper.stdinEnabled = false
    }

    stdout: StdioCollector {
      onStreamFinished: {
        const job = helper.job
        helper.job = null
        if (job) job.done(this.text)
        Qt.callLater(root.next)
      }
    }
  }

  IpcHandler {
    target: "gmail"
    enabled: Settings.widgetEnabled("gmail")

    // Connects to the inbox again now (after a network or password problem).
    function check(): void {
      root.lookUpPassword()
    }

    // Opens the inbox in the browser.
    function open(): void {
      root.openInbox()
    }

    // What a notification's Open does: runs the widget's click action when
    // it has one (a mail app, or a web app, which opens on the mail), else
    // opens `link` (the mail, or the inbox) in the browser.
    function openMail(link: string): void {
      if (!WidgetActions.run("gmail", link)) Qt.openUrlExternally(link)
    }

    // The inbox's unread conversations, or -1 while it isn't watched or not
    // known yet.
    function unread(): int {
      return root.unread
    }

    // What the watching is at, as JSON: { active, hasPassword, unread, error }
    // (see the properties above).
    function status(): string {
      return JSON.stringify({ active: root.active, hasPassword: root.hasPassword, unread: root.unread, error: root.error })
    }

    // Takes the app password out of the keyring (the watcher stops).
    function forgetPassword(): void {
      root.setPassword("")
    }
  }
}
