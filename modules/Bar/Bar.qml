import Quickshell
import QtQuick
import qs.components
import qs.config
import qs.modules.Bar.Widgets

// Top bar, replicated across every connected screen.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      margins.top: Theme.barMarginTop
      margins.left: Theme.barMarginLeft
      margins.right: Theme.barMarginRight

      implicitHeight: Theme.barHeight
      color: "transparent"

      // Left widgets
      Pill {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        LauncherTrigger {}

        // LanguageTrigger {}

        SettingsTrigger {}

        Separator {}
        Workspaces {}

        Separator {
          visible: activeWindow.toplevel !== null
        }

        ActiveWindow {
          id: activeWindow
        }
      }

      // Middle widget
      Pill {
        anchors.centerIn: parent

        Clock {}

        Separator {}

        WallpaperTrigger {}

        ThemeTrigger {}

        
      }

      // Right widgets
      Pill {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        flattenBottomRight: powerMenu.menuOpen

        Tray {}

        Separator {}

        CpuUsage {}

        Separator {}

        RamUsage {}

        Separator {}

        DiskUsage {}

        Separator {}

        NetworkSpeed {}

        Separator {}

        Volume {}

        Separator {}

        PowerMenu {
          id: powerMenu
        }
      }
    }
  }
}

