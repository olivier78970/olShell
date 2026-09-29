import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// The chat AI panel (ChatAiPanel.qml), built only while it is open and freed
// once it closes, so a panel that isn't showing takes no memory. Its `chatai`
// IPC target lives here, so it answers while the panel isn't built; the
// question and answer live in services/ChatAi.qml.
Scope {
  IpcHandler {
    target: "chatai"

    // Opens or closes the panel.
    function toggle(): void {
      ChatAiState.toggle()
    }

    // Opens the panel (if it isn't) and asks `question` there.
    function ask(question: string): void {
      if (!ChatAiState.visible) ChatAiState.toggle()
      ChatAi.ask(question)
    }

    // Stops the question being answered.
    function cancel(): void {
      ChatAi.cancel()
    }

    // The last answer (Markdown), "" while there is none.
    function answer(): string {
      return ChatAi.answer
    }

    // The providers as JSON, in order: [{ id, name, protocol, url, model,
    // builtin, key, picked, models, modelsStatus }], `model` its default (the
    // settings'), `picked` the one picked in the panel instead ("" for none),
    // `key` whether it has an API key
    // (the keys stay in the keyring), `models` the ids of the models it
    // lists and `modelsStatus` how listing them went ("ok", "loading", the
    // error, or "" before any try).
    function providers(): string {
      return JSON.stringify(ChatAi.known.map(provider => Object.assign({
        key: ChatAi.hasKey[provider.id] === true,
        picked: ChatAiState.models[provider.id] ?? "",
        models: (ChatAi.models[provider.id] ?? []).map(model => model.id),
        modelsStatus: ChatAi.modelsStatus[provider.id] ?? ""
      }, provider)))
    }

    // Picks the provider asked next, by id.
    function select(id: string): void {
      ChatAi.select(id)
    }

    // Picks the model provider `id` is asked until the shell restarts, in
    // place of its default; "" goes back to the default.
    function selectModel(id: string, model: string): void {
      ChatAi.selectModel(id, model)
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: ChatAiState.visible
  }

  LazyLoader {
    active: linger.active

    ChatAiPanel {}
  }
}
