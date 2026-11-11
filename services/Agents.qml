pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The AI agents of the agent bar widget, a fixed list (Claude and Codex, the
// choices of Settings.agentDefault), each an AgentUsage with its plan and
// usage limits; and running the default agent's command line in a terminal,
// or its desktop app (Claude Desktop, ChatGPT). IPC (target `agent`, while the widget is enabled):
// `open` runs the default agent's command line, `desktop` its desktop app,
// `usage` prints each agent's plan and limits as they were last read.
Singleton {
  id: root

  // Whether the agent widget is enabled (else nothing is asked).
  readonly property bool active: Settings.widgetEnabled("agent")

  readonly property AgentUsage claude: AgentUsage {
    key: "claude"
    name: "Claude"
    icon: "󰫢"
    command: ["claude"]
    desktop: ["claude-desktop"]
    script: Paths.claudeUsageScript
    active: root.active
  }

  readonly property AgentUsage codex: AgentUsage {
    key: "codex"
    name: "Codex"
    icon: "󰚩"
    command: ["codex"]
    desktop: ["chatgpt"]
    script: Paths.codexUsageScript
    active: root.active
  }

  // Every agent, in the order of Settings.choices.agentDefault.
  readonly property var all: [root.claude, root.codex]
  // The default agent (Settings.agentDefault), and every agent with it
  // first, as the widget's menu lists them.
  readonly property AgentUsage current: root.all.find(agent => agent.key === Settings.agentDefault) ?? root.claude
  readonly property var ordered: [root.current].concat(root.all.filter(agent => agent !== root.current))
  // The same, without the agents that aren't installed.
  readonly property var installed: root.ordered.filter(agent => agent.installed)

  // The agent whose key (a choice of Settings.agentDefault) is `key`, or
  // null.
  function byKey(key) {
    return root.all.find(agent => agent.key === key) ?? null
  }

  // Whether the agent `key` is installed, so it may be the default agent.
  function isInstalled(key) {
    return root.byKey(key)?.installed ?? false
  }

  // Looks for every agent's command line again (as the default agent's list
  // opens in the settings).
  function lookUp() {
    root.all.forEach(agent => agent.lookUp())
  }

  // Reads every agent's plan and limits again, unless read less than
  // `maxAge` seconds ago.
  function refresh(maxAge) {
    root.all.forEach(agent => agent.refresh(maxAge))
  }

  // Runs the default agent's command line in a terminal from
  // Settings.agentFolder, in a floating window in the middle of the screen
  // with Settings.agentFloating, else in a tiled one.
  function openAgent() {
    const command = root.current.command
    if (Settings.agentFloating) TerminalApps.launch(command, Settings.agentFolder)
    else Quickshell.execDetached({ command: TerminalApps.terminalCommand(command), workingDirectory: Settings.agentFolder })
  }

  // Starts the default agent's desktop app: Claude Desktop for Claude, the
  // ChatGPT app for Codex. Already running, it brings its window forward
  // instead.
  function openDesktop() {
    if (root.current.desktop.length > 0) Quickshell.execDetached(root.current.desktop)
  }

  IpcHandler {
    target: "agent"
    enabled: root.active

    // Runs the default agent's command line in a terminal.
    function open(): void {
      root.openAgent()
    }

    // Starts the default agent's desktop app.
    function desktop(): void {
      root.openDesktop()
    }

    // Each agent's plan, then its limits (window in minutes, percent used
    // and when it resets), as last read; the call also reads them again
    // for the next time.
    function usage(): string {
      root.refresh(30)
      return root.ordered.map(agent => agent.describe()).join("\n")
    }
  }
}
