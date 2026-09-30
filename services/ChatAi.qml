pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Asks the chat AI panel's question: one question, one answer, no
// conversation, of Anthropic, OpenAI or an OpenAI-compatible provider the
// user added. The request runs in
// scripts/ai-ask.py, which lets the AI search and read the user's files
// (read-only, see there) and the shell's documentation, run the shell's IPC
// calls if the settings allow it, and looks the provider's API key up in the secret
// keyring itself. Held here rather than in the panel, so an answer still
// arrives while the panel is closed and is there when it opens again.
// Each provider's models are listed from its API once it has a key, for the
// settings to pick one from.
Singleton {
  id: root

  // The built-in providers, by id: their name, the API they speak and its
  // address, which the settings don't show, and whether the AI can search the
  // web through them (`webSearch`, see scripts/ai-ask.py).
  readonly property var builtins: ({
    anthropic: { name: "Anthropic", protocol: "anthropic", url: "https://api.anthropic.com/v1", webSearch: true },
    openai: { name: "OpenAI", protocol: "openai", url: "https://api.openai.com/v1", webSearch: true },
    xai: { name: "xAI", protocol: "openai", url: "https://api.x.ai/v1", webSearch: true },
    google: { name: "Google", protocol: "openai", url: "https://generativelanguage.googleapis.com/v1beta/openai", webSearch: false }
  })

  // Every provider of Settings.chatAiProviders, in order: { id (its name in
  // the keyring), name, protocol, url, model, index (its place in the
  // setting), builtin }.
  readonly property var known: Settings.chatAiProviders.map((provider, index) => provider.builtin
    ? Object.assign({ id: provider.builtin, model: provider.model, index: index, builtin: true }, root.builtins[provider.builtin])
    : { id: provider.id, name: provider.name, protocol: "openai", url: provider.url, model: provider.model, index: index, builtin: false })

  // The tools the AI may use (scripts/ai-ask.py's names), each with the
  // setting turning it on or off.
  readonly property var toolKeys: [
    { name: "list_dir", key: "chatAiListDir" },
    { name: "find_files", key: "chatAiFindFiles" },
    { name: "search_text", key: "chatAiSearchText" },
    { name: "read_file", key: "chatAiReadFile" },
    { name: "web_search", key: "chatAiWebSearch" },
    { name: "web_fetch", key: "chatAiWebFetch" },
    { name: "shell_docs_search", key: "chatAiShellDocs" },
    { name: "shell_docs_read", key: "chatAiShellDocs" },
    { name: "shell_settings", key: "chatAiShellDocs" },
    { name: "shell_ipc_list", key: "chatAiShellIpc" },
    { name: "shell_ipc_call", key: "chatAiShellIpc" },
    { name: "shell_ipc_propose", key: "chatAiShellIpc" }
  ]

  // The providers that can be asked (the built-in ones once they have a key;
  // an added one may be a local server needing none), and the one that is:
  // the one picked in the panel, else the default one of the settings (when it
  // can be asked), else the first. Each with `model` the one
  // it is asked (the one picked in the panel, else its default) and
  // `defaultModel` the one set in the settings.
  readonly property var providers: root.known
    .filter(provider => !provider.builtin || root.hasKey[provider.id] === true)
    .map(provider => Object.assign({}, provider, { defaultModel: provider.model, model: ChatAiState.models[provider.id] || provider.model }))
  readonly property var provider: root.providers.find(provider => provider.id === ChatAiState.provider)
    ?? root.providers.find(provider => provider.id === Settings.chatAiDefaultProvider) ?? root.providers[0] ?? null
  // Whether the panel asks the default provider (see provider) with its default
  // model: nothing is picked in the panel, or what is picked is that.
  readonly property bool onDefault: (root.provider?.id ?? "") === (root.providers.find(provider => provider.id === Settings.chatAiDefaultProvider) ?? root.providers[0])?.id
    && Object.keys(ChatAiState.models).length === 0
  // The id of the default provider of the settings (Settings.chatAiDefaultProvider,
  // else the first provider), for the settings to show as picked.
  readonly property string defaultProviderId: (root.known.find(provider => provider.id === Settings.chatAiDefaultProvider) ?? root.known[0])?.id ?? ""

  // The last question, the provider asked and its answer (Markdown), the
  // tools the AI used on the way ({ name, arg, path }), and what went wrong
  // ("" if nothing). Saved in ChatAiState.json once answered (see save), and
  // read back from it when the shell starts.
  property string question: saved.adapter.question
  property string askedProvider: saved.adapter.askedProvider
  property string answer: saved.adapter.answer
  property var steps: saved.adapter.steps
  property string error: saved.adapter.error
  // What asking it used, the totals of the provider's requests ({ requests,
  // input, output, cached, reasoning, searches }, see scripts/ai-ask.py),
  // saved with the answer; empty before a first one.
  property var usage: saved.adapter.usage
  // The shell actions the AI proposed under its answer ({ label, target,
  // function, args }, see scripts/ai-ask.py's shell_ipc_propose), each run
  // by a click (see runAction); saved with the answer. And how running each
  // went, by index: { status: "running", "done" or "failed", result: what
  // the call printed }, until the next question.
  property var actions: saved.adapter.actions
  property var actionResults: ({})
  // The questions asked, the oldest first, for the question box to step back
  // through (at most Settings.chatAiHistory); saved with the answer.
  property var history: saved.adapter.history
  readonly property bool busy: asker.running

  // Which providers have an API key in the keyring, by id (see refreshKeys).
  property var hasKey: ({})
  // Each provider's models, by id: [{ id, name }], the newest first; and how
  // listing them went: "loading", "ok", or the error ("" before any try).
  property var models: ({})
  property var modelsStatus: ({})

  function providerOf(id) {
    return root.known.find(provider => provider.id === id) ?? null
  }

  // Asks `text` of the current provider, replacing the last question and
  // answer. Ignored while a question is still being answered.
  function ask(text) {
    const question = (text ?? "").trim()
    if (question.length === 0 || root.busy) return
    root.question = question
    const kept = root.history.filter(entry => entry !== question).concat([question])
    root.history = Settings.chatAiHistory > 0 ? kept.slice(-Settings.chatAiHistory) : []
    root.answer = ""
    root.steps = []
    root.error = ""
    root.usage = {}
    root.actions = []
    root.actionResults = {}
    root.askedProvider = root.provider ? root.provider.name : ""
    if (!root.provider) {
      root.error = I18n.tr("chatAi.error.noProvider")
      root.save()
      return
    }
    if (root.provider.model === "") {
      root.error = I18n.tr("chatAi.error.noModel", root.provider.name)
      root.save()
      return
    }
    asker.command = ["python3", Paths.aiAskScript, "--provider", root.provider.id,
      "--protocol", root.provider.protocol, "--url", root.provider.url, "--model", root.provider.model,
      "--folders", Settings.chatAiFolders, "--exclude", Settings.chatAiExclude,
      "--tools", root.toolKeys.filter(tool => Settings[tool.key]).map(tool => tool.name).join(","),
      "--shell", Paths.shellDir, "--language", I18n.language,
      "--", question]
    asker.running = true
  }

  // Stops the question being answered.
  function cancel() {
    if (!root.busy) return
    asker.running = false
    root.error = I18n.tr("chatAi.cancelled")
  }

  // Forgets the last question and its answer, here and in the saved file.
  // Ignored while a question is being answered.
  function clear() {
    if (root.busy) return
    root.question = ""
    root.askedProvider = ""
    root.answer = ""
    root.steps = []
    root.error = ""
    root.usage = {}
    root.actions = []
    root.actionResults = {}
    root.save()
  }

  // Runs proposed action `index` (see actions) as the shell's IPC call,
  // unless one is already running; with the chat's shell commands turned
  // off since it was proposed, nothing runs.
  function runAction(index) {
    const action = root.actions[index]
    if (!action || actionRunner.running || !Settings.chatAiShellIpc) return
    root.setActionResult(index, "running", "")
    actionRunner.index = index
    actionRunner.command = ["quickshell", "ipc", "-p", Paths.shellDir, "call", action.target, action.function].concat(action.args ?? [])
    actionRunner.running = true
  }

  function setActionResult(index, status, result) {
    const results = Object.assign({}, root.actionResults)
    results[index] = { status: status, result: result }
    root.actionResults = results
  }

  // Saves the last question and its answer, to show again after a restart.
  function save() {
    saved.adapter.question = root.question
    saved.adapter.askedProvider = root.askedProvider
    saved.adapter.answer = root.answer
    saved.adapter.steps = root.steps
    saved.adapter.error = root.error
    saved.adapter.usage = root.usage
    saved.adapter.actions = root.actions
    saved.adapter.history = root.history
    saved.writeAdapter()
  }

  // Picks the provider asked next, by id.
  function select(id) {
    ChatAiState.provider = id
  }

  // Goes back to the default provider and its default model, forgetting what
  // was picked in the panel.
  function selectDefault() {
    ChatAiState.provider = ""
    ChatAiState.models = {}
  }

  // Picks the model provider `id` is asked, until the shell restarts; its
  // default (the settings') or "" goes back to that default.
  function selectModel(id, model) {
    const models = Object.assign({}, ChatAiState.models)
    const provider = root.known.find(other => other.id === id)
    if (!model || (provider && model === provider.model)) delete models[id]
    else models[id] = model
    ChatAiState.models = models
  }

  // Reads again which providers have a key, then lists the models of those
  // that have one and whose models aren't listed yet, or failed to be (the
  // settings do it when their chat AI page shows, the panel when it opens).
  function refreshKeys() {
    root.run(["python3", Paths.aiKeyScript, "has"].concat(root.known.map(provider => provider.id)), null, text => {
      try {
        root.hasKey = JSON.parse(text)
      } catch (error) {
        root.hasKey = {}
      }
      for (const provider of root.known) {
        if (provider.builtin && !root.hasKey[provider.id]) root.setModels(provider.id, [], "")
        else if (!["ok", "loading"].includes(root.modelsStatus[provider.id])) root.listModels(provider.id)
      }
    })
  }

  // Lists provider `id`'s models from its API. When the model set for it
  // isn't among them (none is, at first), the first, its newest, is picked.
  function listModels(id) {
    const provider = root.providerOf(id)
    if (!provider) return
    root.setModels(id, root.models[id] ?? [], "loading")
    root.run(["python3", Paths.aiAskScript, "--provider", id, "--protocol", provider.protocol, "--url", provider.url, "--list-models"], null, text => {
      let result
      try {
        result = JSON.parse(text)
      } catch (error) {
        result = { error: text.trim() || "?" }
      }
      if (result.error !== undefined) {
        root.setModels(id, [], result.error)
        return
      }
      root.setModels(id, result.models, "ok")
      // (Looked up again: the list may have changed while it was read.)
      const current = root.providerOf(id)
      if (current && result.models.length > 0 && !result.models.some(model => model.id === current.model)) {
        Settings.setChatAiProvider(current.index, { model: result.models[0].id })
      }
    })
  }

  function setModels(id, list, status) {
    const models = Object.assign({}, root.models)
    const statuses = Object.assign({}, root.modelsStatus)
    models[id] = list
    statuses[id] = status
    root.models = models
    root.modelsStatus = statuses
  }

  // Puts provider `id`'s API key in the keyring (an empty key takes it
  // out), then lists its models again (an added provider's address changed
  // does the same, without a key change: see forgetModels). The key goes to the script through
  // its standard input, never on its command line.
  function setKey(id, key) {
    const trimmed = (key ?? "").trim()
    root.setModels(id, [], "")
    if (trimmed === "") root.run(["python3", Paths.aiKeyScript, "clear", id], null, () => root.refreshKeys())
    else root.run(["python3", Paths.aiKeyScript, "set", id], trimmed, () => root.refreshKeys())
  }

  // Lists provider `id`'s models again, as when its key changes.
  function forgetModels(id) {
    root.setModels(id, [], "")
    root.refreshKeys()
  }

  // Takes added provider `id` out of the list, and its key out of the keyring.
  function remove(id) {
    const provider = root.providerOf(id)
    if (!provider || provider.builtin) return
    root.run(["python3", Paths.aiKeyScript, "clear", id], null, () => root.refreshKeys())
    Settings.removeChatAiProvider(provider.index)
  }

  // The helper commands waiting their turn ({ command, input, done }): one
  // runs at a time, `input` written to its standard input (null for none),
  // `done` given what it printed.
  property var queue: []

  function run(command, input, done) {
    root.queue.push({ command: command, input: input, done: done })
    root.next()
  }

  function next() {
    if (helper.running || helper.job !== null || root.queue.length === 0) return
    const job = root.queue.shift()
    helper.job = job
    helper.command = job.command
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
      // Closes its standard input, so the script reads the key to its end.
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

  Process {
    id: asker

    stdout: SplitParser {
      onRead: line => {
        let message
        try {
          message = JSON.parse(line)
        } catch (error) {
          return
        }
        if (message.event === "tool") root.steps = root.steps.concat([{ name: message.name, arg: message.arg, path: message.path }])
        else if (message.event === "action") root.actions = root.actions.concat([{ label: message.label, target: message.target, function: message.function, args: message.args }])
        else if (message.event === "usage") root.usage = { requests: message.requests, input: message.input, output: message.output, cached: message.cached, reasoning: message.reasoning, searches: message.searches }
        else if (message.event === "answer") root.answer = message.text
        else if (message.event === "error") root.error = message.message
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 && root.answer === "" && root.error === "") root.error = I18n.tr("chatAi.error.failed", exitCode)
      root.save()
    }
  }

  // The last question and its answer, as saved (git-ignored); the
  // properties above follow it once it is read, a moment after the shell
  // starts. The file only exists once a question has been answered.
  FileView {
    id: saved
    path: Paths.chatAiState
    blockLoading: true
    printErrors: false

    JsonAdapter {
      property string question: ""
      property string askedProvider: ""
      property string answer: ""
      property var steps: []
      property string error: ""
      property var usage: ({})
      property var actions: []
      property var history: []
    }
  }

  // Runs a proposed action (see runAction). What it prints is its result:
  // a value, or the shell's complaint (which it prints with a zero exit
  // code too, so an output starting like one counts as failed). Read once
  // it has exited and both its outputs are in, whichever comes last.
  Process {
    id: actionRunner

    property int index: -1
    property int exitCode: 0
    property int parts: 0

    // (The shell exports QS_CONFIG_PATH; -p names it anyway.)
    environment: ({ QS_CONFIG_PATH: null })

    onStarted: actionRunner.parts = 0

    stdout: StdioCollector {
      id: actionOutput
      onStreamFinished: actionRunner.partDone()
    }
    stderr: StdioCollector {
      id: actionErrors
      onStreamFinished: actionRunner.partDone()
    }

    onExited: (exitCode, exitStatus) => {
      actionRunner.exitCode = exitCode
      actionRunner.partDone()
    }

    function partDone() {
      actionRunner.parts += 1
      if (actionRunner.parts < 3) return
      const output = (actionOutput.text + actionErrors.text).trim()
      const failed = actionRunner.exitCode !== 0 || /^(Too (few|many) arguments|No (target|function)|ipc:)/.test(output)
      root.setActionResult(actionRunner.index, failed ? "failed" : "done", output)
    }
  }

  Component.onCompleted: root.refreshKeys()
}
