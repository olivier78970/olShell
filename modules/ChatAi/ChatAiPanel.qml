import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// One question to an AI, one answer: no conversation. Placed like the other
// panels (Settings.chatAiPlacement), toggled from outside via:
//   quickshell -p . ipc call chatai toggle
// Type the question and press Enter; while the AI works, the files it
// searches and reads show under the question (it can't change any, see
// scripts/ai-ask.py), then its answer. The button at the top right (or
// Ctrl+M) opens a menu picking the provider and model asked, Tab switches
// the provider, Up/Down/PageUp/PageDown scroll the answer, Ctrl+Shift+C
// copies it, Escape closes (the answer still arrives, and shows when the
// panel opens again).
ModalPanel {
  id: root

  maxPanelWidth: 860
  // As tall as what it shows (the margins, the title, the question box and
  // the answer), up to all the room the screen has for it (see
  // ModalPanel's fitScreen); a longer answer scrolls.
  fitScreen: true
  // (While the menu is open, at least tall enough to hold it.)
  maxPanelHeight: Math.max(32 + titleRow.height + questionBox.height + 24 + answerColumn.implicitHeight
      + (statusBox.visible ? statusBox.height + 12 : 0),
    root.menuOpen ? 16 + titleRow.height + 4 + modelMenu.height + 16 : 0)
  placement: Settings.chatAiPlacement
  focusTarget: input

  open: ChatAiState.visible
  onCloseRequested: ChatAiState.visible = false
  onOpened: {
    input.text = ""
    root.menuOpen = false
    ChatAi.refreshKeys()
  }

  // Picks the provider `steps` places after the current one, around at the
  // ends.
  function cycleProvider(steps) {
    const providers = ChatAi.providers
    if (providers.length < 2) return
    const at = Math.max(0, providers.indexOf(ChatAi.provider))
    ChatAi.select(providers[(at + steps + providers.length) % providers.length].id)
  }

  // The answer cut at its Markdown images: { text } for the Markdown around
  // them, and { image, alt } for each image, in order (see findImage).
  readonly property var segments: {
    const answer = ChatAi.answer
    const segments = []
    let last = 0
    for (let found = root.findImage(answer, 0); found !== null; found = root.findImage(answer, found.end)) {
      const text = answer.slice(last, found.start)
      if (text.trim() !== "") segments.push({ text: root.linkPaths(text) })
      segments.push({ image: found.image, alt: found.alt })
      last = found.end
    }
    const rest = answer.slice(last)
    if (rest.trim() !== "") segments.push({ text: root.linkPaths(rest) })
    return segments
  }

  // The first Markdown image of `text` from `from` on, ![alt](address), as
  // { start, end, image, alt }, or null. Laxer than Markdown, as the AI
  // writes paths as they are: the address runs to the ")" matching its "(",
  // spaces and parentheses included, and may be between <> and followed by
  // a "title".
  function findImage(text, from) {
    for (let start = text.indexOf("![", from); start >= 0; start = text.indexOf("![", start + 2)) {
      const close = text.indexOf("](", start + 2)
      if (close < 0) return null
      const alt = text.slice(start + 2, close)
      // An alt text doesn't span paragraphs or hold another "]".
      if (alt.includes("]") || alt.includes("\n\n")) continue
      let depth = 0
      let end = -1
      for (let at = close + 2; at < text.length && text[at] !== "\n"; at++) {
        if (text[at] === "(") depth++
        else if (text[at] === ")" && depth-- === 0) {
          end = at
          break
        }
      }
      if (end < 0) continue
      let image = text.slice(close + 2, end).trim().replace(/\s+"[^"]*"$/, "").trim()
      if (image.startsWith("<") && image.endsWith(">")) image = image.slice(1, -1).trim()
      if (image !== "") return { start: start, end: end + 1, image: image, alt: alt }
    }
    return null
  }

  // The tallest an image is shown.
  readonly property real maxImageHeight: 420

  // The web images of the answer that may be loaded: those clicked. Not
  // loaded by themselves, since the address of an image is a way out for
  // what the AI read: a web page it read could have it write an image whose
  // address holds the content of the user's files, sent to the page's author
  // by just loading it. Forgotten with each answer.
  property var allowedImages: []

  Connections {
    target: ChatAi

    function onAnswerChanged() {
      root.allowedImages = []
    }
  }

  // The address an image is loaded from: a web one as it is, a file's path
  // (from ~ or /, or a file:// address) as a file:// address; "" for anything
  // else.
  function imageUrl(source) {
    if (/^https?:\/\//i.test(source)) return source
    return root.fileUrl(source.replace(/^file:\/\//i, ""))
  }

  // The file:// address of a path (absolute, or from ~), "" for anything
  // else. The AI often writes a path already encoded as an address
  // ("Dark%20Souls"), since Markdown wants no space in one: it is decoded
  // first, not encoded twice (%2520). Parentheses are encoded too, as they
  // would end a Markdown link's address.
  function fileUrl(path) {
    let plain = path
    if (/%[0-9A-Fa-f]{2}/.test(plain)) {
      try {
        plain = decodeURIComponent(plain)
      } catch (error) {}
    }
    if (plain.startsWith("~/") || plain === "~") plain = Quickshell.env("HOME") + plain.slice(1)
    if (!plain.startsWith("/")) return ""
    return "file://" + encodeURI(plain).replace(/\(/g, "%28").replace(/\)/g, "%29")
  }

  // The site a web address is on.
  function hostOf(url) {
    const match = /^https?:\/\/([^/?#]+)/i.exec(url)
    return match ? match[1] : url
  }

  // A tool the AI used, in the shell's language.
  function stepText(step) {
    const key = "chatAi.tool." + step.name
    const text = I18n.tr(key, step.path, step.arg)
    return text !== key ? text : step.name + " " + step.arg + " " + step.path
  }

  // The whole exchange as plain text: the question, what the AI looked at
  // and its answer, for copying it all at once.
  function exchangeText() {
    const parts = [ChatAi.question]
    if (ChatAi.steps.length > 0) parts.push(ChatAi.steps.map(step => "- " + root.stepText(step)).join("\n"))
    parts.push(ChatAi.error !== "" ? ChatAi.error : ChatAi.answer)
    return parts.filter(part => part !== "").join("\n\n")
  }

  // What the last question used, in one line: the tokens sent and received
  // (with those read from the provider's cache and spent reasoning, when
  // there were any), the web searches, and the requests when it took several
  // (see ChatAi.usage).
  function usageText(usage) {
    const count = number => Number(number).toLocaleString(Qt.locale(), "f", 0)
    const parts = [I18n.tr("chatAi.usage.tokens", count(usage.input), count(usage.output))]
    if (usage.cached > 0) parts.push(I18n.tr("chatAi.usage.cached", count(usage.cached)))
    if (usage.reasoning > 0) parts.push(I18n.tr("chatAi.usage.reasoning", count(usage.reasoning)))
    if (usage.searches > 0) parts.push(I18n.tr("chatAi.usage.searches", count(usage.searches)))
    if (usage.requests > 1) parts.push(I18n.tr("chatAi.usage.requests", count(usage.requests)))
    return parts.join("  ·  ")
  }

  // The AI's access options, in the order of the settings' Access tab, for the
  // icons in the title row: the icon, its name, whether its setting is on and
  // whether the provider asked can do it (the web search needs one with a web
  // search tool), and `shown: false` for the one only Anthropic has, reading
  // pages, which isn't shown for the others (see ChatAi.providers).
  readonly property var accessOptions: [
    { glyph: "󰉋", label: I18n.tr("chatAi.access.listDir"), enabled: Settings.chatAiListDir, supported: true },
    { glyph: "󰱼", label: I18n.tr("chatAi.access.findFiles"), enabled: Settings.chatAiFindFiles, supported: true },
    { glyph: "󱎸", label: I18n.tr("chatAi.access.searchText"), enabled: Settings.chatAiSearchText, supported: true },
    { glyph: "󰈙", label: I18n.tr("chatAi.access.readFile"), enabled: Settings.chatAiReadFile, supported: true },
    { glyph: "󰖟", label: I18n.tr("chatAi.access.webSearch"), enabled: Settings.chatAiWebSearch, supported: ChatAi.provider?.webSearch ?? false },
    { glyph: "󰌷", label: I18n.tr("chatAi.access.webFetch"), enabled: Settings.chatAiWebFetch, supported: ChatAi.provider?.protocol === "anthropic", shown: ChatAi.provider?.protocol === "anthropic" },
    { glyph: "󱓷", label: I18n.tr("chatAi.access.shellDocs"), enabled: Settings.chatAiShellDocs, supported: true },
    { glyph: "󰆍", label: I18n.tr("chatAi.access.shellIpc"), enabled: Settings.chatAiShellIpc, supported: true }
  ]

  // Whether the menu picking the provider and model is open, the entry the
  // keys are on in it, and the tallest it gets (it scrolls past that).
  property bool menuOpen: false
  property int menuHighlight: -1
  readonly property real maxMenuHeight: 360

  // The menu's entries, in order: { heading } for each provider that can be
  // asked, then { providerId, model, name, isDefault } for each of its
  // models (isDefault for the one set in the settings), or { note } saying
  // why it has none to pick from.
  readonly property var menuEntries: ChatAi.providers.reduce((entries, provider) => {
    entries.push({ heading: provider.name })
    const listed = ChatAi.models[provider.id] ?? []
    // Without a list yet: the model picked and the default, those set.
    const models = listed.length > 0 ? listed : [...new Set([provider.model, provider.defaultModel])]
      .filter(model => model !== "").map(model => ({ id: model, name: model }))
    for (const model of models) {
      entries.push({ providerId: provider.id, model: model.id, name: model.name, isDefault: model.id === provider.defaultModel })
    }
    const status = ChatAi.modelsStatus[provider.id] ?? ""
    if (listed.length === 0) {
      entries.push({ note: status === "loading" || status === "" ? I18n.tr("settings.chatAi.models.loading")
        : status === "ok" ? I18n.tr("settings.chatAi.models.none") : I18n.tr("settings.chatAi.models.error", status) })
    }
    return entries
  }, [])

  // `markdown` with its paths made links (file://), so a click opens them
  // (see showPath), each followed by a folder icon (reveal:file://) showing
  // it in its folder in the file manager (see revealPath): the absolute ones and those from ~, in
  // code (`~/Notes/todo.md`, spaces allowed) or not (up to a space). Code
  // blocks and links are left as they are.
  function linkPaths(markdown) {
    // The path's link, then a folder icon showing it in its folder (see
    // revealPath).
    const link = (text, path) => "[" + text + "](" + root.fileUrl(path) + ") [" + root.folderIcon + "](reveal:" + root.fileUrl(path) + ")"
    const isPath = text => /^(~\/|\/)[^\s\/]/.test(text) || text === "~" || text === "/"
    // In turn: a code span, a link (left as it is), and a path after a space,
    // an opening bracket or quote, or the start of a line; a path's
    // punctuation at its end is the sentence's.
    const pattern = /(`[^`\n]+`)|(\[[^\]\n]*\]\([^)\n]*\))|(^|[\s(>"'«])((?:~\/|\/)[^\s`<>()\[\]"'«»]+)/gm
    // Code blocks (between ``` lines) are left as they are.
    return markdown.split(/(```[\s\S]*?```)/).map((part, index) => index % 2 === 1 ? part : part.replace(pattern, (match, code, existing, before, path) => {
      if (code) {
        const inner = code.slice(1, -1).trim()
        return isPath(inner) && !inner.includes("\n") ? link(code, inner) : code
      }
      if (existing) return existing
      const trimmed = path.replace(/[.,;:!?]+$/, "")
      if (!isPath(trimmed) || trimmed.split("/").length < 3 && !trimmed.startsWith("~/")) return match
      return before + link(trimmed, trimmed) + path.slice(trimmed.length)
    })).join("")
  }

  // The content types whose default application runs the file rather than
  // shows it (programs, launchers, Windows programs through Wine, Java
  // archives, scripts): a click on a path in the answer never runs one, it
  // shows it in the file manager instead.
  readonly property var runnableTypes: ["application/x-executable", "application/x-pie-executable",
    "application/x-sharedlib", "application/x-desktop", "application/x-ms-dos-executable",
    "application/x-msdownload", "application/vnd.microsoft.portable-executable", "application/x-msi",
    "application/x-appimage", "application/vnd.appimage", "application/x-java-archive",
    "application/x-shellscript", "text/x-shellscript", "application/x-flatpak", "application/x-flatpakref"]

  // Opens a path (a file:// address): a folder in the default file manager;
  // a file with the default application for its type (GLib's `gio open`,
  // which falls back on the type's parents, so a Python script opens in the
  // text editor), or when there's none, or when that application would run
  // it (runnableTypes), shown selected in its folder in the file manager
  // (through its FileManager1 D-Bus interface, as browsers' "Show in folder"
  // do), else its folder opened. A path that no longer exists opens its
  // folder. The path goes to the command as an argument, never into its
  // text. The panel closes, out of the way of what opens (the answer shows
  // again when it opens again).
  function showPath(url) {
    ChatAiState.visible = false
    const path = decodeURIComponent(url.slice("file://".length))
    const folder = path.replace(/\/[^/]*\/?$/, "") || "/"
    Quickshell.execDetached(["sh", "-c",
      'if [ -d "$1" ]; then exec xdg-open "$1"; fi; '
      + 'if [ ! -e "$1" ]; then exec xdg-open "$3"; fi; '
      + 'type=$(gio info -a standard::content-type "$1" 2>/dev/null | sed -n "s/.*standard::content-type: //p"); '
      + 'case " $4 " in *" $type "*) ;; *) gio open "$1" 2>/dev/null && exit 0 ;; esac; '
      + root.revealCommand,
      "sh", path, url, folder, root.runnableTypes.join(" ")])
  }

  // Shows a path (a file:// address) selected in its folder in the file
  // manager, whatever it is, else opens its folder (see showPath). The
  // panel closes, as for showPath.
  function revealPath(url) {
    ChatAiState.visible = false
    const path = decodeURIComponent(url.slice("file://".length))
    const folder = path.replace(/\/[^/]*\/?$/, "") || "/"
    Quickshell.execDetached(["sh", "-c", root.revealCommand, "sh", path, url, folder])
  }

  // The link of the answer whose tooltip is (about to be) shown, where the
  // pointer was (in panel coordinates), and whether it's visible yet.
  property string tipLink: ""
  property real tipX: 0
  property real tipY: 0
  property bool tipShown: false

  // The pointer rests on a link: show its tooltip once it stops moving for
  // a moment (and leave it where it is while it moves on the same link).
  // Called for every hover event, and a still pointer gets one each time
  // the window redraws (the question box's blinking cursor): only a real
  // move starts the wait again.
  function hoverLink(link, point) {
    if (root.tipLink === link && root.tipX === point.x && root.tipY === point.y) return
    if (root.tipLink !== link) root.tipShown = false
    root.tipLink = link
    if (!root.tipShown) {
      root.tipX = point.x
      root.tipY = point.y
      tipTimer.restart()
    }
  }

  function leaveLink() {
    tipTimer.stop()
    root.tipShown = false
    root.tipLink = ""
  }

  // What a link's tooltip says: where it leads (a file's path from ~, a web
  // address as it is), or for a folder icon, that it shows the file in the
  // file manager.
  function tipText(link) {
    const reveal = link.startsWith("reveal:")
    const target = reveal ? link.slice("reveal:".length) : link
    if (!target.startsWith("file://")) return target
    let path = target.slice("file://".length)
    try {
      path = decodeURIComponent(path)
    } catch (error) {}
    const home = Quickshell.env("HOME")
    if (path === home || path.startsWith(home + "/")) path = "~" + path.slice(home.length)
    return reveal ? I18n.tr("chatAi.tip.reveal", path) : path
  }

  // Opens a web address in the browser, closing the panel as showPath does.
  function openWeb(url) {
    ChatAiState.visible = false
    Qt.openUrlExternally(url)
  }

  // The shell command showing "$2" (a file:// address) selected in its
  // folder "$3", through the file manager's FileManager1 D-Bus interface (as
  // browsers' "Show in folder" do), else opening that folder.
  readonly property string revealCommand: 'busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 '
    + 'org.freedesktop.FileManager1 ShowItems ass 1 "$2" "" >/dev/null 2>&1 || exec xdg-open "$3"'

  // The icon after each path, and on each image of this computer, showing it
  // in its folder.
  readonly property string folderIcon: "󰉋"

  // The name of the model a provider asks (from its list, else its id).
  function modelName(provider) {
    const listed = (ChatAi.models[provider.id] ?? []).find(model => model.id === provider.model)
    return listed ? listed.name : provider.model
  }

  function toggleMenu() {
    if (root.menuOpen) {
      root.menuOpen = false
      return
    }
    root.menuHighlight = root.menuEntries.findIndex(entry => entry.model !== undefined && ChatAi.provider !== null
      && entry.providerId === ChatAi.provider.id && entry.model === ChatAi.provider.model)
    if (root.menuHighlight < 0) root.menuHighlight = root.menuEntries.findIndex(entry => entry.model !== undefined)
    root.menuOpen = true
    Qt.callLater(() => menuList.positionViewAtIndex(Math.max(0, root.menuHighlight), ListView.Contain))
  }

  // Moves the menu's highlight `steps` models on (negative: back), past the
  // headings and notes, stopping at the ends.
  function moveHighlight(steps) {
    const pickable = root.menuEntries.map((entry, index) => entry.model !== undefined ? index : -1).filter(index => index >= 0)
    if (pickable.length === 0) return
    const at = Math.max(0, pickable.indexOf(root.menuHighlight))
    root.menuHighlight = pickable[Math.max(0, Math.min(pickable.length - 1, at + steps))]
    menuList.positionViewAtIndex(root.menuHighlight, ListView.Contain)
  }

  // Asks `entry`'s provider next, with its model (in place of the default
  // set in the settings, which stays as it is), and closes the menu.
  function pick(entry) {
    if (!entry || entry.model === undefined) return
    ChatAi.select(entry.providerId)
    ChatAi.selectModel(entry.providerId, entry.model)
    root.menuOpen = false
  }

  // Which question of ChatAi.history the question box shows (counted back
  // from the newest), -1 for what was being typed, which draft keeps.
  property int historyAt: -1
  property string draft: ""

  // The text selected with the mouse in the question, the answer or the error
  // (never more than one at a time) and the TextEdit holding it. Focus stays
  // in the question box, so Ctrl+C there copies this when it has no
  // selection of its own (see the question box's Keys.onPressed).
  property string selection: ""
  property var selectionOwner: null

  // Called when `edit`'s selection changes.
  function noteSelection(edit) {
    if (edit.selectedText === "") {
      if (root.selectionOwner === edit) {
        root.selectionOwner = null
        root.selection = ""
      }
      return
    }
    const previous = root.selectionOwner
    root.selectionOwner = edit
    root.selection = edit.selectedText
    if (previous && previous !== edit) previous.deselect()
  }

  // Steps the question box `direction` questions back (1) or forward (-1)
  // through the history, keeping what was typed to come back to.
  function browseHistory(direction) {
    const at = root.historyAt + direction
    if (at < -1 || at >= ChatAi.history.length) return
    if (root.historyAt === -1) root.draft = input.text
    root.historyAt = at
    input.text = at === -1 ? root.draft : ChatAi.history[ChatAi.history.length - 1 - at]
    input.cursorPosition = input.text.length
  }

  onKeyPressed: event => {
    const control = (event.modifiers & Qt.ControlModifier) !== 0
    const shift = (event.modifiers & Qt.ShiftModifier) !== 0
    // While the menu is open: it has the arrows, Enter and Escape.
    if (root.menuOpen) {
      if (event.key === Qt.Key_Escape || (control && event.key === Qt.Key_M)) root.menuOpen = false
      else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) root.moveHighlight(event.key === Qt.Key_Down ? 1 : -1)
      else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) root.moveHighlight(event.key === Qt.Key_PageDown ? 8 : -8)
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.pick(root.menuEntries[root.menuHighlight])
      else return
      event.accepted = true
      return
    }
    if (control && event.key === Qt.Key_M) {
      if (ChatAi.providers.length > 0) root.toggleMenu()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      root.cycleProvider(event.key === Qt.Key_Backtab || shift ? -1 : 1)
      event.accepted = true
    } else if (control && shift && event.key === Qt.Key_C) {
      if (ChatAi.question !== "") Quickshell.clipboardText = root.exchangeText()
      event.accepted = true
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
      root.browseHistory(event.key === Qt.Key_Up ? 1 : -1)
      event.accepted = true
    } else {
      const step = event.key === Qt.Key_PageDown ? answerView.height * 0.9 : event.key === Qt.Key_PageUp ? -answerView.height * 0.9 : 0
      if (step === 0) return
      answerView.contentY = Math.max(0, Math.min(answerView.contentHeight - answerView.height, answerView.contentY + step))
      event.accepted = true
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    // The title, and a button naming the provider and model asked, which
    // opens the menu to pick them (see modelMenu).
    Item {
      id: titleRow
      width: parent.width
      height: Math.max(title.implicitHeight, modelButton.height)

      ThemedText {
        id: title
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr("chatAi.title")
        sizeScale: 1.2
        font.bold: true
      }

      // One icon for each of the AI's access options of the settings (its tools:
      // folders, files, the web, the shell), in the accent color when it is on
      // and crossed and dimmed when it is off or the provider asked can't do it,
      // with which one and why on hover.
      Row {
        id: accessRow
        visible: Settings.chatAiShowAccess && ChatAi.providers.length > 0
        anchors.right: defaultButton.visible ? defaultButton.left : modelButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Repeater {
          model: root.accessOptions

          Item {
            id: accessItem

            required property var modelData
            readonly property bool on: accessItem.modelData.enabled && accessItem.modelData.supported

            visible: accessItem.modelData.shown ?? true
            width: accessGlyph.implicitWidth
            height: modelButton.height

            ThemedText {
              id: accessGlyph
              anchors.centerIn: parent
              text: accessItem.modelData.glyph
              sizeScale: 0.9
              font.strikeout: !accessItem.on
              color: accessItem.on ? Theme.accentColor : Theme.textColor
              opacity: accessItem.on ? 1 : 0.4
            }

            HoverHandler {
              id: accessHover
            }

            DisabledTooltip {
              anchorItem: accessItem
              text: accessItem.on ? I18n.tr("chatAi.access.on", accessItem.modelData.label)
                : !accessItem.modelData.supported ? I18n.tr("chatAi.access.unsupported", accessItem.modelData.label, ChatAi.provider?.name ?? "")
                : I18n.tr("chatAi.access.off", accessItem.modelData.label)
              visible: accessHover.hovered
            }
          }
        }
      }

      // Goes back to the default provider and model, once another is picked.
      Rectangle {
        id: defaultButton
        visible: ChatAi.providers.length > 0 && !ChatAi.onDefault
        anchors.right: modelButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: defaultText.implicitWidth + 24
        height: modelButton.height
        radius: Theme.radiusFor(height)
        color: defaultMouse.containsMouse ? Theme.borderColor : "transparent"
        border.color: Theme.outlineColor
        border.width: 1

        ThemedText {
          id: defaultText
          anchors.centerIn: parent
          text: I18n.tr("chatAi.default")
          sizeScale: 0.85
        }

        MouseArea {
          id: defaultMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: ChatAi.selectDefault()
        }
      }

      Rectangle {
        id: modelButton
        visible: ChatAi.providers.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(modelText.implicitWidth + 24, titleRow.width - title.width - 16 - (accessRow.visible ? accessRow.width + 8 : 0) - (defaultButton.visible ? defaultButton.width + 8 : 0))
        height: modelText.implicitHeight + 10
        radius: Theme.radiusFor(height)
        color: root.menuOpen || modelMouse.containsMouse ? Theme.borderColor : "transparent"
        border.color: root.menuOpen ? Theme.accentColor : Theme.outlineColor
        border.width: 1

        ThemedText {
          id: modelText
          anchors.centerIn: parent
          width: Math.min(implicitWidth, parent.width - 24)
          elide: Text.ElideMiddle
          text: ChatAi.provider ? ChatAi.provider.name + "  ·  " + (root.modelName(ChatAi.provider) || I18n.tr("chatAi.menu.noModel")) + "  󰅀" : ""
          sizeScale: 0.85
        }

        MouseArea {
          id: modelMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleMenu()
        }
      }
    }

    // The question box.
    Rectangle {
      id: questionBox
      width: parent.width
      height: 44
      radius: Theme.radiusFor(height)
      color: Theme.backgroundColor
      border.color: Theme.outlineColor
      border.width: Theme.borderWidth

      ThemedText {
        id: questionIcon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "󰭹"
        opacity: 0.7
      }

      TextInput {
        id: input
        anchors.left: questionIcon.right
        anchors.leftMargin: 10
        anchors.right: actionButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.textColor
        selectionColor: Theme.accentColor
        selectedTextColor: Theme.backgroundColor
        font.family: Theme.fontFamily
        font.weight: Theme.fontWeight
        font.letterSpacing: Theme.fontLetterSpacing
        font.italic: Theme.fontItalic
        font.underline: Theme.fontUnderline
        font.pixelSize: Theme.fontSize()

        // Ctrl+C with nothing selected here copies the selection made in the
        // answer above (see selection).
        Keys.onPressed: event => {
          if ((event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_C
              && input.selectedText === "" && root.selectionOwner && root.selection !== "") {
            Quickshell.clipboardText = root.selection
            event.accepted = true
          }
        }

        onAccepted: {
          // (Enter goes on to the panel, which picks from the open menu.)
          if (root.menuOpen || ChatAi.busy || input.text.trim() === "") return
          ChatAi.ask(input.text)
          input.text = ""
          root.historyAt = -1
          answerView.contentY = 0
        }

        ThemedText {
          visible: input.text.length === 0
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          elide: Text.ElideRight
          text: !ChatAi.provider ? I18n.tr("chatAi.error.noProvider")
            : I18n.tr("chatAi.placeholder", ChatAi.provider.name + (ChatAi.provider.model ? " (" + ChatAi.provider.model + ")" : ""))
          opacity: 0.5
        }
      }

      // Send, or stop the question being answered.
      IconButton {
        id: actionButton
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        icon: ChatAi.busy ? "󰓛" : "󰒊"
        sizeScale: 1.1
        onClicked: {
          if (ChatAi.busy) ChatAi.cancel()
          else input.accepted()
        }
      }
    }

    // The question asked, what the AI looked at, and its answer.
    Flickable {
      id: answerView
      width: parent.width
      height: parent.height - titleRow.height - questionBox.height - (statusBox.visible ? statusBox.height + parent.spacing : 0) - parent.spacing * 2
      clip: true
      contentWidth: width
      contentHeight: answerColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      // A slim scroll position indicator at the right edge, when the answer
      // is longer than the room (like the popup menus').
      Rectangle {
        parent: answerView
        visible: answerView.contentHeight > answerView.height
        x: answerView.width - width - 1
        y: answerView.visibleArea.yPosition * answerView.height
        width: 3
        height: answerView.visibleArea.heightRatio * answerView.height
        radius: width / 2
        color: Theme.textColor
        opacity: 0.35
      }

      Column {
        id: answerColumn
        width: answerView.width
        spacing: 10

        // The question, whose text can be selected.
        TextEdit {
          id: questionText
          visible: ChatAi.question !== ""
          width: parent.width
          readOnly: true
          selectByMouse: true
          onSelectedTextChanged: root.noteSelection(questionText)
          activeFocusOnPress: false
          wrapMode: TextEdit.Wrap
          text: ChatAi.question
          color: Theme.textColor
          selectionColor: Theme.accentColor
          selectedTextColor: Theme.backgroundColor
          font.family: Theme.fontFamily
          font.weight: Font.Bold
          font.letterSpacing: Theme.fontLetterSpacing
          font.pixelSize: Theme.fontSize()
        }

        // Between the question and the answer (or where it is) when the AI
        // looked at nothing: what it looked at follows the question directly.
        Separator {
          visible: ChatAi.question !== "" && ChatAi.steps.length === 0 && (ChatAi.busy || ChatAi.error !== "" || ChatAi.answer !== "")
        }

        // What the AI searched and read: one line with the latest step and
        // how many there were, which a click opens into one line each, whose
        // text can be selected.
        Column {
          id: stepsBox
          width: parent.width
          spacing: 2
          visible: ChatAi.steps.length > 0

          // Whether every step is listed rather than only the latest.
          property bool expanded: false

          MouseArea {
            width: parent.width
            height: stepsSummary.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: stepsBox.expanded = !stepsBox.expanded

            ThemedText {
              id: stepsSummary
              width: parent.width
              elide: Text.ElideMiddle
              text: (stepsBox.expanded ? "󰅀 " : "󰅂 ") + I18n.tr("chatAi.steps.summary", ChatAi.steps.length,
                ChatAi.steps.length > 0 ? root.stepText(ChatAi.steps[ChatAi.steps.length - 1]) : "")
              sizeScale: 0.8
              opacity: 0.6
            }
          }

          // Every step, one per line, in one block so that a selection can
          // run over several of them (a long one wraps rather than being cut).
          TextEdit {
            id: stepsText
            visible: stepsBox.expanded
            width: parent.width
            leftPadding: 20
            readOnly: true
            selectByMouse: true
            onSelectedTextChanged: root.noteSelection(stepsText)
            activeFocusOnPress: false
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
            text: stepsBox.expanded ? ChatAi.steps.map(step => root.stepText(step)).join("\n") : ""
            color: Theme.textColor
            opacity: 0.6
            selectionColor: Theme.accentColor
            selectedTextColor: Theme.backgroundColor
            font.family: Theme.fontFamily
            font.weight: Theme.fontWeight
            font.letterSpacing: Theme.fontLetterSpacing
            font.pixelSize: Theme.fontSize() * 0.8
          }
        }

        // Between what the AI looked at and its answer (or where it is).
        Separator {
          visible: ChatAi.steps.length > 0 && (ChatAi.busy || ChatAi.error !== "" || ChatAi.answer !== "")
        }

        ThemedText {
          visible: ChatAi.busy
          text: I18n.tr("chatAi.thinking", ChatAi.askedProvider)
          opacity: 0.6
          SequentialAnimation on opacity {
            running: ChatAi.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 700 }
            NumberAnimation { to: 0.7; duration: 700 }
          }
        }

        // The error, whose text can be selected.
        TextEdit {
          id: errorText
          visible: ChatAi.error !== ""
          width: parent.width
          readOnly: true
          selectByMouse: true
          onSelectedTextChanged: root.noteSelection(errorText)
          activeFocusOnPress: false
          wrapMode: TextEdit.Wrap
          text: ChatAi.error
          color: Theme.accentColor
          selectionColor: Theme.accentColor
          selectedTextColor: Theme.backgroundColor
          font.family: Theme.fontFamily
          font.weight: Theme.fontWeight
          font.letterSpacing: Theme.fontLetterSpacing
          font.pixelSize: Theme.fontSize()
        }

        // The answer, in Markdown, cut at its images: its text can be
        // selected and its links open in the browser; an image on this
        // computer shows at once, one from the web only once clicked (see
        // allowedImages).
        Repeater {
          model: root.segments

          Item {
            id: segment

            required property var modelData
            readonly property bool image: segment.modelData.image !== undefined
            readonly property string url: segment.image ? root.imageUrl(segment.modelData.image) : ""
            readonly property bool remote: /^https?:/i.test(segment.url)
            readonly property bool shown: segment.image && segment.url !== "" && (!segment.remote || root.allowedImages.includes(segment.url))

            width: answerColumn.width
            height: !segment.image ? answerText.implicitHeight
              : picture.status === Image.Ready ? picture.height
              : imageNote.implicitHeight + 16

            TextEdit {
              id: answerText
              visible: !segment.image
              width: parent.width
              readOnly: true
              selectByMouse: true
              onSelectedTextChanged: root.noteSelection(answerText)
              wrapMode: TextEdit.Wrap
              textFormat: TextEdit.MarkdownText
              text: segment.image ? "" : segment.modelData.text
              color: Theme.textColor
              selectionColor: Theme.accentColor
              selectedTextColor: Theme.backgroundColor
              font.family: Theme.fontFamily
              font.weight: Theme.fontWeight
              font.letterSpacing: Theme.fontLetterSpacing
              font.pixelSize: Theme.fontSize()
              // A path (see linkPaths) shows in the file manager, the
              // rest opens in the browser.
              onLinkActivated: link => {
                if (link.startsWith("reveal:")) root.revealPath(link.slice("reveal:".length))
                else if (link.startsWith("file://")) root.showPath(link)
                else if (link.startsWith("/") || link.startsWith("~/")) root.showPath(root.fileUrl(link))
                else root.openWeb(link)
              }
              // Keeps the keyboard in the question box.
              activeFocusOnPress: false

              // A pointing hand over a link, the text cursor elsewhere (the
              // text can be selected).
              HoverHandler {
                cursorShape: answerText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                // The link's tooltip (see hoverLink).
                onPointChanged: {
                  if (answerText.hoveredLink !== "") root.hoverLink(answerText.hoveredLink, answerText.mapToItem(root.panel, point.position.x, point.position.y))
                }
              }
              onHoveredLinkChanged: if (answerText.hoveredLink === "") root.leaveLink()
            }

            // The image, as wide as it is up to the panel's width and at most
            // `maxImageHeight` tall; a click opens it in its application (or
            // the browser).
            Image {
              id: picture
              visible: segment.shown && picture.status === Image.Ready
              source: segment.shown ? segment.url : ""
              asynchronous: true
              fillMode: Image.PreserveAspectFit
              readonly property real ratio: picture.sourceSize.width > 0 ? picture.sourceSize.height / picture.sourceSize.width : 0
              width: Math.min(parent.width, picture.sourceSize.width, picture.ratio > 0 ? root.maxImageHeight / picture.ratio : parent.width)
              height: picture.width * picture.ratio

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // An image of this computer opens as its path does.
                onClicked: segment.remote ? root.openWeb(segment.url) : root.showPath(segment.url)
              }

              // Shows an image of this computer in its folder.
              Rectangle {
                visible: !segment.remote
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                width: revealIcon.implicitWidth + 12
                height: revealIcon.implicitHeight + 6
                radius: Theme.radiusFor(height)
                color: Theme.fade(Theme.backgroundColor, revealMouse.containsMouse ? 0.95 : 0.75)
                border.color: Theme.outlineColor
                border.width: 1

                ThemedText {
                  id: revealIcon
                  anchors.centerIn: parent
                  text: root.folderIcon
                  color: revealMouse.containsMouse ? Theme.accentColor : Theme.textColor
                }

                MouseArea {
                  id: revealMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.revealPath(segment.url)
                }
              }
            }

            // In place of the image: a web one not shown yet (a click shows
            // it), one loading, or one that can't be shown.
            Rectangle {
              visible: segment.image && picture.status !== Image.Ready
              width: Math.min(parent.width, imageNote.implicitWidth + 24)
              height: imageNote.implicitHeight + 16
              radius: Theme.radiusFor(height)
              color: noteMouse.containsMouse && !segment.shown ? Theme.borderColor : "transparent"
              border.color: Theme.outlineColor
              border.width: 1

              ThemedText {
                id: imageNote
                anchors.centerIn: parent
                width: Math.min(implicitWidth, segment.width - 24)
                elide: Text.ElideMiddle
                text: "󰋩  " + (!segment.shown && segment.remote ? I18n.tr("chatAi.image.remote", root.hostOf(segment.url))
                  : picture.status === Image.Loading ? I18n.tr("chatAi.image.loading")
                  : I18n.tr("chatAi.image.error", segment.modelData.alt || segment.modelData.image))
                sizeScale: 0.85
                opacity: 0.8
              }

              MouseArea {
                id: noteMouse
                anchors.fill: parent
                enabled: !segment.shown && segment.remote
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.allowedImages = root.allowedImages.concat([segment.url])
              }
            }
          }
        }

        // The shell actions the AI proposed (see ChatAi.actions): a button
        // each, running its IPC call when clicked, with the call beside it
        // and then what it gave (or why it failed).
        Column {
          visible: ChatAi.actions.length > 0 && !ChatAi.busy
          width: parent.width
          spacing: 6

          Repeater {
            model: ChatAi.actions

            Row {
              id: actionRow
              required property var modelData
              required property int index
              // How running it went (see ChatAi.actionResults), null before.
              readonly property var outcome: ChatAi.actionResults[index] ?? null
              readonly property string command: [modelData.target, modelData.function].concat(modelData.args ?? []).join(" ")
              width: parent.width
              spacing: 10

              Rectangle {
                id: actionChip
                width: Math.min(actionLabel.implicitWidth + actionGlyph.implicitWidth + 32, actionRow.width * 0.6)
                height: actionLabel.implicitHeight + 12
                radius: Theme.radiusFor(height)
                color: actionMouse.containsMouse && actionMouse.enabled ? Theme.borderColor : "transparent"
                border.color: actionRow.outcome && actionRow.outcome.status === "failed" ? Theme.warningColor : Theme.accentColor
                border.width: 1
                opacity: Settings.chatAiShellIpc ? 1 : 0.5

                ThemedText {
                  id: actionGlyph
                  anchors.left: parent.left
                  anchors.leftMargin: 12
                  anchors.verticalCenter: parent.verticalCenter
                  text: !actionRow.outcome ? "󰐊" : actionRow.outcome.status === "running" ? "󰔟"
                    : actionRow.outcome.status === "done" ? "󰄬" : "󰅖"
                  color: actionRow.outcome && actionRow.outcome.status === "failed" ? Theme.warningColor : Theme.accentColor
                }

                ThemedText {
                  id: actionLabel
                  anchors.left: actionGlyph.right
                  anchors.leftMargin: 8
                  anchors.right: parent.right
                  anchors.rightMargin: 12
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  text: actionRow.modelData.label
                }

                MouseArea {
                  id: actionMouse
                  anchors.fill: parent
                  enabled: Settings.chatAiShellIpc && !(actionRow.outcome && actionRow.outcome.status === "running")
                  hoverEnabled: true
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: ChatAi.runAction(actionRow.index)
                }
              }

              // The call, then what it gave; or why it can't run.
              ThemedText {
                anchors.verticalCenter: actionChip.verticalCenter
                width: actionRow.width - actionChip.width - actionRow.spacing
                elide: Text.ElideRight
                text: !Settings.chatAiShellIpc ? I18n.tr("chatAi.actions.off")
                  : actionRow.outcome && actionRow.outcome.result !== "" ? actionRow.command + "  →  " + actionRow.outcome.result
                  : actionRow.command
                color: actionRow.outcome && actionRow.outcome.status === "failed" ? Theme.warningColor : Theme.textColor
                sizeScale: 0.8
                opacity: 0.6
              }
            }
          }
        }

        // Nothing asked yet.
        ThemedText {
          visible: Settings.chatAiShowHint && ChatAi.question === "" && ChatAi.error === ""
          width: parent.width
          wrapMode: Text.WordWrap
          text: I18n.tr("chatAi.hint")
          opacity: 0.5
        }
      }
    }

    // Along the bottom, what the last question used, and the buttons to
    // clear the question with its answer (also from the saved file) and
    // to copy them.
    Item {
      id: statusBox
      // What the usage says, "" when there is nothing to show.
      readonly property string usage: Settings.chatAiShowUsage && ChatAi.question !== "" && (ChatAi.usage.requests ?? 0) > 0
        ? root.usageText(ChatAi.usage) : ""

      visible: ChatAi.question !== ""
      width: parent.width
      height: Math.max(usageLabel.implicitHeight, buttons.height)

      ThemedText {
        id: usageLabel
        anchors.left: parent.left
        anchors.right: buttons.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: statusBox.usage
        sizeScale: 0.75
        opacity: 0.5
      }

      Row {
        id: buttons
        visible: !ChatAi.busy
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        ThemedText {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("chatAi.clear")
          sizeScale: 0.8
          opacity: 0.6
        }

        IconButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰃢"
          sizeScale: 1
          onClicked: ChatAi.clear()
        }

        Item {
          width: 12
          height: 1
        }

        ThemedText {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.tr("chatAi.copy")
          sizeScale: 0.8
          opacity: 0.6
        }

        IconButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰆏"
          sizeScale: 1
          onClicked: Quickshell.clipboardText = root.exchangeText()
        }
      }
    }
  }

  // A thin line across the answer column, between its parts: the tray
  // menus' soft hairline, inset from the sides, with rounded ends (the
  // column's spacing is the room around it).
  component Separator: Item {
    width: parent ? parent.width : 0
    height: 1

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      radius: 0.5
      color: Theme.separatorColor
      opacity: 0.5
    }
  }

  // A click beside the open menu closes it (without closing the panel).
  MouseArea {
    anchors.fill: parent
    visible: root.menuOpen
    z: 9
    onClicked: root.menuOpen = false
  }

  // The menu picking the provider and model asked: each provider that can
  // be asked, with the models its API lists under it (the one set when there
  // is no list yet); the current one ticked.
  Rectangle {
    id: modelMenu
    visible: root.menuOpen
    z: 10
    x: parent.width - 16 - width
    y: 16 + titleRow.height + 4
    width: Math.min(parent.width - 32, Math.max(modelButton.width, Theme.fontSize() * 26))
    height: Math.min(menuList.contentHeight + 8, root.maxMenuHeight)
    radius: Theme.radiusFor(40)
    color: Theme.backgroundColor
    border.color: Theme.outlineColor
    border.width: 1

    ListView {
      id: menuList
      anchors.fill: parent
      anchors.margins: 4
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.menuOpen ? root.menuEntries : []

      delegate: Item {
        id: entry

        required property var modelData
        required property int index
        readonly property bool pickable: entry.modelData.model !== undefined
        readonly property bool current: entry.pickable && ChatAi.provider !== null
          && entry.modelData.providerId === ChatAi.provider.id && entry.modelData.model === ChatAi.provider.model

        width: ListView.view.width
        height: entry.pickable ? 30 : 26

        Rectangle {
          anchors.fill: parent
          visible: entry.pickable
          radius: Theme.radiusFor(height)
          color: entry.index === root.menuHighlight ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.22) : "transparent"
        }

        // A provider's name, or why it lists no model.
        ThemedText {
          visible: !entry.pickable
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          elide: Text.ElideRight
          text: entry.modelData.heading ?? entry.modelData.note ?? ""
          color: entry.modelData.heading ? Theme.accentColor : Theme.textColor
          font.bold: entry.modelData.heading !== undefined
          sizeScale: 0.8
          opacity: entry.modelData.heading ? 1 : 0.6
        }

        // A model: a tick for the current one, its name, and its id when
        // that says something else.
        Row {
          visible: entry.pickable
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          ThemedText {
            width: 16
            text: entry.current ? "󰄬" : ""
            color: Theme.accentColor
            sizeScale: 0.85
          }

          ThemedText {
            id: modelLabel
            width: Math.min(implicitWidth, parent.width - 24)
            elide: Text.ElideRight
            text: entry.modelData.name ?? ""
            sizeScale: 0.85
          }

          // The one set in the settings.
          ThemedText {
            id: defaultTag
            visible: entry.modelData.isDefault === true
            text: I18n.tr("chatAi.menu.default")
            color: Theme.accentColor
            sizeScale: 0.75
          }

          ThemedText {
            visible: entry.pickable && entry.modelData.name !== entry.modelData.model
            width: Math.max(0, parent.width - 24 - modelLabel.width - 8 - (defaultTag.visible ? defaultTag.width + 8 : 0))
            elide: Text.ElideMiddle
            text: entry.modelData.model ?? ""
            sizeScale: 0.75
            opacity: 0.5
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: entry.pickable
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.menuHighlight = entry.index
          onClicked: root.pick(entry.modelData)
        }
      }
    }
  }

  Timer {
    id: tipTimer
    interval: 500
    onTriggered: root.tipShown = true
  }

  // Tooltip saying where the hovered link of the answer leads.
  Rectangle {
    id: tooltip

    visible: root.tipShown && root.tipLink !== ""
    z: 10
    width: tipLabel.width + 20
    height: tipLabel.implicitHeight + 14
    // Just below the pointer, kept inside the panel; above it when there's
    // no room underneath.
    x: Math.max(8, Math.min(root.tipX + 12, root.panel.width - width - 8))
    y: root.tipY + 24 + height > root.panel.height - 8 ? root.tipY - height - 12 : root.tipY + 24
    radius: Theme.radiusFor(height)
    color: Theme.backgroundColor
    border.color: Theme.outlineColor
    border.width: Theme.borderWidth

    ThemedText {
      id: tipLabel
      x: 10
      y: 7
      width: Math.min(implicitWidth, root.panel.width - 48)
      elide: Text.ElideMiddle
      text: root.tipLink !== "" ? root.tipText(root.tipLink) : ""
      sizeScale: 0.8
    }
  }
}
