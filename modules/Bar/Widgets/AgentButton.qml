import QtQuick
import qs.components
import qs.config
import qs.services

// The agent widget, for the AI agents of services/Agents.qml (Claude and
// Codex), drawn as a four-pointed star. A left click runs the default
// agent's command line (Settings.agentDefault: Claude Code or Codex) in a
// terminal window (from Settings.agentFolder, floating or not by
// Settings.agentFloating); a middle click starts its desktop app, Claude
// Desktop or ChatGPT (or brings its window forward). A right click opens a menu with a
// section for each installed agent, the default one first: its plan, then each of its
// usage limits with how much is used and how long until it starts again
// (read again while the menu is open).
Item {
  id: root

  readonly property bool menuOpen: menu.open
  // The time now, ticking while the menu is open, for the countdowns.
  property date now: new Date()

  anchors.verticalCenter: parent.verticalCenter
  implicitWidth: icon.implicitWidth
  implicitHeight: icon.height

  BarText {
    id: icon
    anchors.centerIn: parent
    text: "󰫢"
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) menu.open = !menu.open
      else {
        menu.open = false
        if (mouse.button === Qt.MiddleButton) Agents.openDesktop()
        else Agents.openAgent()
      }
    }
  }

  // Reads the limits again as the menu opens (unless they're fresh) and
  // every minute while it stays open, and moves the countdowns on.
  Timer {
    running: menu.open
    triggeredOnStart: true
    interval: 60000
    repeat: true
    onTriggered: {
      root.now = new Date()
      Agents.refresh(30)
    }
  }

  // How long until `date`: "2 d 5 h", "3 h 04 min" or "12 min".
  function remaining(date) {
    if (!date) return "?"
    const minutes = Math.max(0, Math.ceil((date.getTime() - root.now.getTime()) / 60000))
    const days = Math.floor(minutes / 1440)
    const hours = Math.floor(minutes % 1440 / 60)
    if (days > 0) return I18n.tr("agent.days", days, hours)
    if (hours > 0) return I18n.tr("agent.hours", hours, String(minutes % 60).padStart(2, "0"))
    return I18n.tr("agent.minutes", minutes)
  }

  // A limit's name, from the length of its window: "5-hour limit", "Weekly
  // limit", "30-day limit".
  function windowName(minutes) {
    if (minutes === 10080) return I18n.tr("agent.window.week")
    if (minutes % 1440 === 0) return I18n.tr("agent.window.days", minutes / 1440)
    return I18n.tr("agent.window.hours", Math.round(minutes / 60))
  }

  // A limit: its name, a gauge of the share used (in the warning color from
  // 80%), and the percent used with the time until it starts again.
  component UsageLimit: Column {
    id: usage

    property var limit: null
    readonly property color tint: (usage.limit?.percent ?? 0) >= 80 ? Theme.warningColor : Theme.accentColor

    topPadding: 6
    spacing: 4

    ThemedText {
      text: root.windowName(usage.limit?.minutes ?? 0)
      color: Theme.accentColor
    }

    // The gauge: an outlined track, so it stands out on the popup's
    // background even when little is used, filled with the share used (at
    // least a round dot as soon as anything is).
    Rectangle {
      width: 240
      height: 10
      radius: height / 2
      color: Qt.alpha(Theme.textColor, 0.12)
      border.width: 1
      border.color: Theme.outlineColor

      Rectangle {
        readonly property real share: Math.min(1, (usage.limit?.percent ?? 0) / 100)

        visible: share > 0
        width: Math.max(parent.height, parent.width * share)
        height: parent.height
        radius: parent.radius
        color: usage.tint
      }
    }

    ThemedText {
      text: I18n.tr("agent.used", usage.limit?.percent ?? 0, root.remaining(usage.limit?.resetsAt ?? null))
      sizeScale: 0.85
    }
  }

  // An agent's section of the menu: a heading with
  // its icon and name over a line, then, set in under it, its plan and its
  // session and weekly limits (or why they aren't known yet). `agent` is the
  // agent (an AgentUsage of Agents); `inset` lines it up with a menu's entries.
  // Its size comes from its text and gauges alone, and the line spans the
  // whole menu, the section's width or more (were the line part of the
  // size, the section and the menu would size each other in a loop).
  component AgentSection: Item {
    id: section

    property var agent: null
    property real inset: 0
    property real topPadding: 2
    property real bottomPadding: 0

    implicitWidth: content.implicitWidth + section.inset * 2
    implicitHeight: content.implicitHeight + section.topPadding + section.bottomPadding

    Column {
      id: content
      x: section.inset
      y: section.topPadding
      spacing: 4

      Row {
        spacing: 8

        ThemedText {
          text: section.agent?.icon ?? ""
          color: Theme.accentColor
        }

        ThemedText {
          text: section.agent?.name ?? ""
          font.bold: true
        }
      }

      // Room for the line, drawn below across the whole menu.
      Item {
        id: lineSlot
        width: 1
        height: 11
      }

      Column {
        leftPadding: 12

        // Said instead of the limits until they are read, or when they can't be.
        ThemedText {
          visible: !section.agent?.loaded || section.agent?.error !== ""
          text: section.agent?.error ? I18n.tr("agent.error." + section.agent.error, section.agent.command[0]) : I18n.tr("agent.loading")
          color: section.agent?.error ? Theme.warningColor : Theme.textColor
        }

        ThemedText {
          visible: section.agent?.loaded ?? false
          text: I18n.tr("agent.plan", section.agent?.plan ?? "")
        }

        ThemedText {
          visible: (section.agent?.loaded ?? false) && section.agent.limits.length === 0
          text: I18n.tr("agent.noLimit")
        }

        Repeater {
          model: section.agent?.loaded ? section.agent.limits : []

          UsageLimit {
            required property var modelData
            limit: modelData
          }
        }
      }
    }

    Item {
      y: content.y + lineSlot.y
      width: Math.max(section.width, section.parent?.width ?? 0)
      height: lineSlot.height

      MenuSeparator {}
    }
  }

  PopupMenu {
    id: menu
    anchorItem: root
    alignCenter: true

    PopupTitle {
      text: I18n.tr("settings.widget.agent")
      inMenu: true
    }

    // Said when no agent is installed.
    ThemedText {
      visible: Agents.installed.length === 0
      leftPadding: 12
      rightPadding: 12
      bottomPadding: 4
      text: I18n.tr("agent.none")
    }

    // Each installed agent, the default one first.
    Repeater {
      model: Agents.installed

      AgentSection {
        required property var modelData
        required property int index
        agent: modelData
        inset: 12
        topPadding: index > 0 ? 10 : 2
        bottomPadding: index === Agents.installed.length - 1 ? 4 : 0
      }
    }
  }
}
