pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Asks the chat AI panel's question: one question, one answer, no
// conversation, of Anthropic, OpenAI or an OpenAI-compatible provider the
// user added. The request runs in
// scripts/ai-ask.py, which lets the AI search and read the user's files
// (read-only, see there) and looks the provider's API key up in the secret
// keyring itself. Held here rather than in the panel, so an answer still
// arrives while the panel is closed and is there when it opens again.
// Each provider's models are listed from its API once it has a key, for the
// settings to pick one from.
Singleton {
  id: root

  // The built-in providers, by id: their name, the API they speak and its
  // address, which the settings don't show.
  readonly property var builtins: ({
    anthropic: { name: "Anthropic", protocol: "anthropic", url: "https://api.anthropic.com/v1" },
    openai: { name: "OpenAI", protocol: "openai", url: "https://api.openai.com/v1" }
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
    { name: "web_fetch", key: "chatAiWebFetch" }
  ]

  // The providers that can be asked (the built-in ones once they have a key;
  // an added one may be a local server needing none), and the one that is:
  // the one picked in the panel, else the first. Each with `model` the one
  // it is asked (the one picked in the panel, else its default) and
  // `defaultModel` the one set in the settings.
  readonly property var providers: root.known
    .filter(provider => !provider.builtin || root.hasKey[provider.id] === true)
    .map(provider => Object.assign({}, provider, { defaultModel: provider.model, model: ChatAiState.models[provider.id] || provider.model }))
  readonly property var provider: root.providers.find(provider => provider.id === ChatAiState.provider) ?? root.providers[0] ?? null

  // The last question, the provider asked and its answer (Markdown), the
  // tools the AI used on the way ({ name, arg, path }), and what went wrong
  // ("" if nothing).
  property string question: ""
  property string askedProvider: ""
  property string answer: ""
  property var steps: []
  property string error: ""
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
    root.answer = ""
    root.steps = []
    root.error = ""
    root.askedProvider = root.provider ? root.provider.name : ""
    if (!root.provider) {
      root.error = I18n.tr("chatAi.error.noProvider")
      return
    }
    if (root.provider.model === "") {
      root.error = I18n.tr("chatAi.error.noModel", root.provider.name)
      return
    }
    asker.command = ["python3", Paths.aiAskScript, "--provider", root.provider.id,
      "--protocol", root.provider.protocol, "--url", root.provider.url, "--model", root.provider.model,
      "--folders", Settings.chatAiFolders, "--exclude", Settings.chatAiExclude,
      "--tools", root.toolKeys.filter(tool => Settings[tool.key]).map(tool => tool.name).join(","),
      "--language", I18n.language,
      "--", question]
    asker.running = true
  }

  // Stops the question being answered.
  function cancel() {
    if (!root.busy) return
    asker.running = false
    root.error = I18n.tr("chatAi.cancelled")
  }

  // Picks the provider asked next, by id.
  function select(id) {
    ChatAiState.provider = id
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
        else if (message.event === "answer") root.answer = message.text
        else if (message.event === "error") root.error = message.message
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 && root.answer === "" && root.error === "") root.error = I18n.tr("chatAi.error.failed", exitCode)
    }
  }

  Component.onCompleted: root.refreshKeys()
}
