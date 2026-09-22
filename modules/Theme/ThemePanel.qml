import QtQuick
import Quickshell.Io
import qs.components
import qs.config
import qs.services

// Screen-centered theme picker, toggled from outside via:
//   quickshell -p . ipc call themes themesToggle
// Themes (see ThemePresets) are browsed in a carousel like the wallpaper
// panel; Enter or a click applies the centered one. The first entry,
// "Automatique", follows the wallpaper's matugen palette; the corner button
// jumps to it and applies it.
CarouselPanel {
  id: root

  readonly property int activeIndex: ThemePresets.presets.findIndex(theme => theme.id === ThemeState.active.id)

  title: I18n.tr("theme.title")
  model: ThemePresets.presets
  maxPanelWidth: 1700
  maxPanelHeight: 520

  visible: ThemePanelState.visible
  onCloseRequested: ThemePanelState.visible = false
  // Open on the theme currently in use.
  onOpened: root.showIndex(Math.max(0, root.activeIndex))
  onAccepted: index => {
    ThemeState.select(ThemePresets.presets[index].id)
    // Re-colors the other apps (Zen...) with the new theme.
    Matugen.applyTheme()
  }

  IpcHandler {
    target: "themes"

    function themesToggle(): void {
      ThemePanelState.toggle()
    }
  }

  delegate: Component {
    CarouselCard {
      id: card

      readonly property bool applied: card.modelData.id === ThemeState.active.id
      // "auto" has no colors of its own: preview the wallpaper's.
      readonly property var colors: card.modelData.colors ?? GeneratedColors.matugenColors

      aspectRatio: 0.85
      selectedScale: 1.4
      color: card.colors.backgroundColor
      bordered: false
      onActivated: root.accept()

      Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 6

        ThemedText {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: card.modelData.id === "auto" ? I18n.tr("theme.auto") : card.modelData.name
          color: card.colors.textColor
          sizeScale: 0.8
        }

        ThemedText {
          visible: text.length > 0
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: card.modelData.id === "auto" ? I18n.tr("theme.autoDescription") : ""
          color: card.colors.textColor
          opacity: 0.7
          sizeScale: 0.55
        }

        // Miniature of the bar's pill with the theme's colors: workspace
        // dots (the active one in the accent color) and clock text.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: miniBar.implicitWidth + 24
          height: 24
          radius: Theme.radiusFor(height)
          color: card.colors.pillColor
          border.color: Theme.outlineOf(card.colors.pillColor, card.colors.textColor)
          border.width: Theme.borderWidth > 0 ? 1 : 0

          Row {
            id: miniBar
            anchors.centerIn: parent
            spacing: 6

            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 8; radius: Theme.radiusFor(height); color: card.colors.accentColor }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.radiusFor(height); color: card.colors.borderColor }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.radiusFor(height); color: card.colors.borderColor }

            ThemedText {
              anchors.verticalCenter: parent.verticalCenter
              text: "12:34"
              color: card.colors.textColor
              sizeScale: 0.55
            }
          }
        }

        // Each color role with its value, shown only for the centered card.
        Column {
          visible: card.current
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 3

          Repeater {
            model: [
              { label: I18n.tr("theme.color.background"), key: "backgroundColor" },
              { label: I18n.tr("theme.color.pill"), key: "pillColor" },
              { label: I18n.tr("theme.color.border"), key: "borderColor" },
              { label: I18n.tr("theme.color.text"), key: "textColor" },
              { label: I18n.tr("theme.color.accent"), key: "accentColor" }
            ]

            Row {
              id: colorRow

              required property var modelData
              readonly property string value: String(card.colors[colorRow.modelData.key])

              spacing: 6

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: Theme.radiusFor(height)
                color: colorRow.value
                border.color: card.colors.textColor
                border.width: 1
              }

              ThemedText {
                width: 48
                text: colorRow.modelData.label
                color: card.colors.textColor
                opacity: 0.7
                sizeScale: 0.5
              }

              ThemedText {
                text: colorRow.value.toUpperCase()
                color: card.colors.textColor
                sizeScale: 0.5
              }
            }
          }
        }
      }

      // Marks the theme currently in use.
      ThemedText {
        visible: card.applied
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        text: "󰄬"
        color: card.colors.accentColor
        sizeScale: 0.7
      }
    }
  }

  PowerMenuOption {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 20
    label: I18n.tr("theme.auto")
    onClicked: {
      // "auto" is always the first entry, so selecting it moves the
      // carousel to it instead of just applying it without visually
      // reflecting the change.
      root.currentIndex = 0
      root.accept()
    }
  }
}
