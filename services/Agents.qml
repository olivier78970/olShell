pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The AI agents of the agent bar widget, a fixed list (Claude, Codex, Grok, Antigravity,
// opencode and Kilo Code, the choices of Settings.agentDefault), each an AgentUsage with its
// plan and usage limits; and running the default agent's command line in a
// terminal, or its desktop app (Claude Desktop, ChatGPT, Grok Desktop,
// Antigravity, OpenCode Desktop). IPC (target `agent`, while the widget is enabled):
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

  readonly property AgentUsage grok: AgentUsage {
    key: "grok"
    name: "Grok"
    icon: "󰧑"
    command: ["grok"]
    desktop: ["grok-desktop"]
    webApp: "Grok"
    script: Paths.grokUsageScript
    active: root.active
  }

  // Google's agent: its CLI (agy) and its desktop app (Antigravity), signed
  // in with the same Google account.
  readonly property AgentUsage antigravity: AgentUsage {
    key: "antigravity"
    name: "Antigravity"
    icon: "󰊭"
    command: ["agy"]
    desktop: ["antigravity"]
    script: Paths.antigravityUsageScript
    active: root.active
  }

  // The open-source agent: its CLI (opencode) and its desktop app (OpenCode
  // Desktop). It signs in to other makers' accounts (an Anthropic API key,
  // Claude Agent...), whose limits their agents' sections show, so it has no
  // limits of its own: its script reads the services it is connected to.
  readonly property AgentUsage opencode: AgentUsage {
    key: "opencode"
    name: "opencode"
    icon: "󰅴"
    command: ["opencode"]
    desktop: ["opencode-desktop"]
    script: Paths.opencodeConnectionsScript
    hasLimits: false
    active: root.active
  }

  // Kilo Code's CLI (kilo), a fork of opencode, without a desktop app on
  // Linux. Like opencode, it signs in to other makers' accounts, so its
  // script reads the services it is connected to.
  readonly property AgentUsage kilo: AgentUsage {
    key: "kilo"
    name: "Kilo Code"
    icon: "󰬒"
    command: ["kilo"]
    desktop: []
    script: Paths.kiloConnectionsScript
    hasLimits: false
    active: root.active
  }

  // Every agent, in the order of Settings.choices.agentDefault.
  readonly property var all: [root.claude, root.codex, root.grok, root.antigravity, root.opencode, root.kilo]
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

  // Runs the command line of `agent` (the default agent when left out) in a
  // terminal from Settings.agentFolder, in a floating window in the middle
  // of the screen with Settings.agentFloating, else in a tiled one.
  function openAgent(agent) {
    const command = (agent ?? root.current).command
    if (Settings.agentFloating) TerminalApps.launch(command, Settings.agentFolder)
    else Quickshell.execDetached({ command: TerminalApps.terminalCommand(command), workingDirectory: Settings.agentFolder })
  }

  // Starts the desktop app of `agent` (the default agent when left out):
  // Claude Desktop for Claude, the ChatGPT app for Codex, Grok Desktop for
  // Grok, the Antigravity app for Antigravity, OpenCode Desktop for opencode;
  // or else the web app standing
  // in for it (the Grok web app for Grok). Already running, it brings its
  // window forward instead. With neither installed, it does nothing.
  function openDesktop(agent) {
    const target = agent ?? root.current
    if (target.desktopFound) Quickshell.execDetached(target.desktop)
    else if (target.webAppEntry) WebApps.launch(target.webAppEntry, "")
  }

  // Does what a click on the widget is set to do (a choice of
  // Settings.choices.agentClick) with the default agent: runs its command
  // line ("cli"), starts its desktop app ("desktop"), or nothing ("none").
  function act(action) {
    if (action === "cli") root.openAgent()
    else if (action === "desktop") root.openDesktop()
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
