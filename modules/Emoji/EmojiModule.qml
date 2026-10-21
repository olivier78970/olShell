import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The emoji panel (EmojiPanel.qml), built only while it is open and freed
// once it closes, so a panel that isn't showing takes no memory. Its `emoji`
// IPC target lives here, so it answers while the panel isn't built.
Scope {
  IpcHandler {
    target: "emoji"
    enabled: Settings.widgetEnabled("emoji")

    // Opens or closes the panel.
    function toggle(): void {
      EmojiPanelState.toggle()
    }

    // Copies `emoji` to the clipboard, as picking it in the panel does
    // (it goes first in the recent ones).
    function copy(emoji: string): void {
      EmojiPanelState.copy(emoji)
    }

    // The emoji copied lately, the newest first, as a JSON list.
    function recent(): string {
      return JSON.stringify(EmojiPanelState.recent)
    }
  }

  // Keeps the panel a moment after it closes, so it can animate away.
  Linger {
    id: linger
    when: EmojiPanelState.visible
  }

  LazyLoader {
    active: linger.active && Settings.widgetEnabled("emoji")

    EmojiPanel {}
  }
}
