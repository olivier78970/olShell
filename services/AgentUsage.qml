import QtQuick
import Quickshell.Io

// One AI agent of the agent widget (see Agents.qml, which holds one for
// each): its name, icon and commands, whether it is installed, and its plan
// and usage limits, read by its script (scripts/claude-usage.py,
// scripts/codex-usage.py) when refresh() is called.
QtObject {
  id: root

  // The agent's key (a choice of Settings.agentDefault), name and icon.
  required property string key
  required property string name
  required property string icon
  // Its command line, run in a terminal, and its desktop app ([] for none).
  required property var command
  property var desktop: []
  // The script printing its plan and limits (see claude-usage.py).
  required property string script
  // Whether it may be asked (while the agent widget is enabled).
  property bool active: true

  // Whether its command line is installed (on the PATH): looked for at
  // startup and before each reading, so installing or removing it is seen
  // the next time the menu opens. True until known, so a menu opened at once
  // doesn't miss it.
  property bool installed: true

  // The plan as its maker names it ("Pro", "Max 5x", "Free"...), "" until
  // known.
  property string plan: ""
  // Its limits, shortest window first: { minutes (the window's length),
  // percent (used), resetsAt (a Date, or null) }.
  property var limits: []
  // What kept them from being read: "" (nothing), "login" (no login, or it
  // was refused: running the agent signs in again), "network" or
  // "rateLimit" (its endpoint refused for being asked too often). The plan
  // and limits last read stay shown meanwhile.
  property string error: ""
  // Whether they were read at least once, and when they were last read.
  property bool loaded: false
  property date updated: new Date(0)
  readonly property bool loading: reader.running

  // After a "rateLimit" answer, the endpoint isn't asked again before this
  // time: 5 minutes later, or later when the endpoint asked to wait longer.
  property date retryAt: new Date(0)
  readonly property int rateLimitPause: 300

  // Reads the plan and limits again, unless they were read less than
  // `maxAge` seconds ago (0 reads them anyway), or the endpoint asked to
  // wait (see retryAt).
  function refresh(maxAge) {
    if (!root.active || reader.running || finder.running) return
    if (Date.now() < root.retryAt.getTime()) return
    if (maxAge > 0 && root.loaded && Date.now() - root.updated.getTime() < maxAge * 1000) return
    root.readAfterFinding = true
    finder.running = true
  }

  // Looks for the command line again, without reading the plan and limits.
  function lookUp() {
    if (!finder.running) finder.running = true
  }

  // Whether the search for the command was started by refresh(), so the
  // plan and limits are read once it is found.
  property bool readAfterFinding: false

  Component.onCompleted: finder.running = true

  // The plan and limits as one line each, for the `agent usage` IPC call.
  function describe() {
    if (!root.installed) return root.name + ": not installed"
    if (root.error !== "") return root.name + ": error: " + root.error
    if (!root.loaded) return root.name + ": not read yet"
    return [root.name + ": " + root.plan].concat(root.limits.map(limit =>
      "  " + limit.minutes + " min: " + limit.percent + "% until " + (limit.resetsAt?.toISOString() ?? "?"))).join("\n")
  }

  // (A QtObject has no default property, so the processes sit here.)
  // Looks for the command line on the PATH, then reads the plan and limits
  // when refresh() asked and it is there.
  readonly property Process finder: Process {
    command: ["which", root.command[0]]
    onExited: code => {
      root.installed = code === 0
      if (root.readAfterFinding && root.installed) reader.running = true
      root.readAfterFinding = false
    }
  }

  readonly property Process reader: Process {
    command: ["python3", root.script]

    stdout: StdioCollector {
      onStreamFinished: {
        let answer = null
        try {
          answer = JSON.parse(this.text)
        } catch (e) {
          console.warn("AgentUsage: unreadable answer from", root.script + ":", this.text)
          return
        }
        root.error = answer.error ?? ""
        if (root.error === "rateLimit")
          root.retryAt = new Date(Date.now() + Math.max(root.rateLimitPause, answer.retryAfter ?? 0) * 1000)
        if (root.error === "") {
          root.plan = answer.plan ?? ""
          root.limits = (answer.limits ?? [])
            .map(limit => ({ minutes: limit.minutes, percent: limit.percent, resetsAt: limit.resetsAt ? new Date(limit.resetsAt) : null }))
            .sort((a, b) => a.minutes - b.minutes)
          root.loaded = true
        }
        root.updated = new Date()
      }
    }
  }
}
