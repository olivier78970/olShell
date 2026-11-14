import QtQuick
import qs.components
import qs.config
import qs.services

// The agent widget, for the AI agents of services/Agents.qml (Claude, Codex,
// Grok, Antigravity, opencode and Kilo Code), drawn as a four-pointed star. A left click and a
// middle click each do what their setting says (Settings.agentClick and
// agentMiddleClick) with the default agent (Settings.agentDefault): by
// default, the left click runs its command line in a terminal window (from
// Settings.agentFolder, floating or not by Settings.agentFloating), and the
// middle click starts its desktop app, Claude Desktop, ChatGPT, Grok Desktop
// Antigravity or OpenCode Desktop (or brings its window forward). A right click opens a menu with a section
// for each installed agent, the default one first: its plan, then each of its
// usage limits with how much is used and how long until it starts again
// (read again while the menu is open); or, for opencode and Kilo Code, which
// have none of their own, the services each is connected to. Beside each agent's name, a button
// runs its command line and another starts its desktop app, when installed.
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
      if (mouse.button === Qt.RightButton) {
        menu.open = !menu.open
        return
      }
      menu.open = false
      if (mouse.button === Qt.MiddleButton) Agents.act(Settings.agentMiddleClick)
      else Agents.act(Settings.agentClick)
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

  // A limit: its name (what it limits, as an Antigravity model group, before the window's
  // when it has one), a gauge of the share used (in the warning color from
  // 80%), and the percent used with the time until it starts again.
  component UsageLimit: Column {
    id: usage

    property var limit: null
    readonly property color tint: (usage.limit?.percent ?? 0) >= 80 ? Theme.warningColor : Theme.accentColor

    topPadding: 6
    spacing: 4

    ThemedText {
      text: (usage.limit?.name ? usage.limit.name + " · " : "") + root.windowName(usage.limit?.minutes ?? 0)
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

  // An agent's section of the menu: its name over a line, then, aligned
  // with it and the menu's title, its plan and its session and weekly limits (or why they aren't known yet). `agent` is the
  // agent (an AgentUsage of Agents); `inset` lines it up with a menu's entries.
  // At the right end of its name's line, a button runs its command line in a
  // terminal and another starts its desktop app, each shown only when its
  // command is on the PATH (looked for again as the menu opens).
  // Its size comes from its text, buttons and gauges alone, and the line and
  // the buttons span the whole menu, the section's width or more (were they
  // part of the size, the section and the menu would size each other in a
  // loop).
  component AgentSection: Item {
    id: section

    property var agent: null
    property real inset: 0
    property real topPadding: 2
    property real bottomPadding: 0

    implicitWidth: Math.max(content.implicitWidth, agentName.implicitWidth + 16 + launchers.implicitWidth) + section.inset * 2
    implicitHeight: content.implicitHeight + section.topPadding + section.bottomPadding

    Column {
      id: content
      x: section.inset
      y: section.topPadding
      spacing: 4

      // The agent's name, larger, in bold and the accent color, so each
      // section's start stands out.
      ThemedText {
        id: agentName
        text: section.agent?.name ?? ""
        font.bold: true
        color: Theme.accentColor
        sizeScale: 1.2
      }

      // Room for the line, drawn below across the whole menu.
      Item {
        id: lineSlot
        width: 1
        height: 11
      }

      Column {
        // For an agent without limits of its own (opencode, Kilo Code): the services it
        // is connected to, once read: a heading, then each service on its own
        // line in bold and the accent color, so it stands out; or how to
        // connect one when there is none.
        ThemedText {
          visible: !(section.agent?.hasLimits ?? true) && section.agent.loaded
          text: section.agent?.connections.length ? I18n.tr("agent.connections")
            : I18n.tr("agent.noConnection", section.agent?.command[0] ?? "")
        }

        Repeater {
          model: !(section.agent?.hasLimits ?? true) && section.agent.loaded ? section.agent.connections : []

          ThemedText {
            required property string modelData
            topPadding: 2
            text: modelData
            font.bold: true
            color: Theme.accentColor
          }
        }

        // Said instead of the limits until they are read, or when they can't
        // be (only the error for an agent without limits of its own).
        ThemedText {
          visible: section.agent?.error ? true : (section.agent?.hasLimits ?? false) && !section.agent.loaded
          text: section.agent?.error ? I18n.tr("agent.error." + section.agent.error, section.agent.command[0]) : I18n.tr("agent.loading")
          color: section.agent?.error ? Theme.warningColor : Theme.textColor
        }

        ThemedText {
          visible: (section.agent?.loaded ?? false) && section.agent.hasLimits
          text: I18n.tr("agent.plan", section.agent?.plan ?? "")
        }

        ThemedText {
          visible: (section.agent?.loaded ?? false) && section.agent.hasLimits && section.agent.limits.length === 0
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

    // The buttons running the agent: its command line, then its desktop app.
    // Clicking one closes the menu.
    Row {
      id: launchers
      x: Math.max(section.width, section.parent?.width ?? 0) - section.inset - width + 6
      y: content.y + agentName.y + (agentName.height - height) / 2

      IconButton {
        visible: section.agent?.installed ?? false
        icon: "󰆍"
        sizeScale: 1
        onClicked: {
          menu.open = false
          Agents.openAgent(section.agent)
        }
      }

      IconButton {
        visible: section.agent?.desktopInstalled ?? false
        icon: "󰍹"
        sizeScale: 1
        onClicked: {
          menu.open = false
          Agents.openDesktop(section.agent)
        }
      }
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
