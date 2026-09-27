import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// A color picker in a popup under `anchorItem`: a square of saturation (left
// to right) and brightness (top to bottom) for the hue picked on the bar
// under it, then the color they make and its value. show() opens it on the
// color `current`; `picked` fires with the new color as "#rrggbb" at every
// change, while the pointer drags too. A click outside closes it, as with
// the shell's other popups. Its button picks a color from the screen instead
// (Apps.screenColorPicker, hyprpicker), closing the popup; the owner can
// hide more around it from `screenPickStarted` and `screenPickFinished`.
PopupWindow {
  id: root

  property Item anchorItem: null
  property string current: "#000000"

  signal picked(string value)
  signal screenPickStarted()
  signal screenPickFinished()

  // The color being picked, as hue, saturation and brightness (0-1 each).
  // The hue is kept apart so a grey (which has none) doesn't lose it.
  property real hue: 0
  property real saturation: 0
  property real brightness: 0
  readonly property color chosen: Qt.hsva(root.hue, root.saturation, root.brightness, 1)

  // Opens the picker on `current`.
  function show() {
    const start = Qt.color(root.current)
    if (start.hsvHue >= 0) root.hue = start.hsvHue
    root.saturation = start.hsvSaturation
    root.brightness = start.hsvValue
    root.visible = true
  }

  function clamp(value) {
    return Math.max(0, Math.min(1, value))
  }

  visible: false
  // Grabbing focus is what makes a click outside dismiss it.
  grabFocus: true
  color: "transparent"
  anchor.item: root.anchorItem
  anchor.edges: Edges.Bottom | Edges.Left
  anchor.gravity: Edges.Bottom | Edges.Right
  anchor.margins.top: 6
  implicitWidth: content.implicitWidth + 24
  implicitHeight: content.implicitHeight + 24

  // Being shown is what gives this window keyboard focus, for Escape.
  onVisibleChanged: if (root.visible) frame.forceActiveFocus()

  Rectangle {
    id: frame
    anchors.fill: parent
    radius: Theme.radiusFor(24)
    color: Theme.pillColor
    border.color: Theme.accentColor
    border.width: 1
    focus: true

    Keys.onEscapePressed: root.visible = false

    Column {
      id: content
      anchors.centerIn: parent
      spacing: 10

      // Saturation and brightness, for the current hue.
      Rectangle {
        id: square
        width: 220
        height: 150
        radius: 4
        color: Qt.hsva(root.hue, 1, 1, 1)

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 1) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1) }
          }
        }

        // Where the color is in the square.
        Rectangle {
          x: root.saturation * square.width - width / 2
          y: (1 - root.brightness) * square.height - height / 2
          width: 14
          height: 14
          radius: 7
          color: root.chosen
          border.color: root.brightness > 0.5 ? "black" : "white"
          border.width: 2
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.CrossCursor

          function pick(mouse) {
            root.saturation = root.clamp(mouse.x / square.width)
            root.brightness = 1 - root.clamp(mouse.y / square.height)
            root.picked(root.chosen.toString())
          }

          onPressed: mouse => pick(mouse)
          onPositionChanged: mouse => pick(mouse)
        }
      }

      // The hues, left to right around the color wheel.
      Rectangle {
        id: hueBar
        width: square.width
        height: 14
        radius: Theme.radiusFor(height)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0 / 6; color: Qt.hsva(0 / 6, 1, 1, 1) }
          GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6, 1, 1, 1) }
          GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6, 1, 1, 1) }
          GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6, 1, 1, 1) }
          GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6, 1, 1, 1) }
          GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6, 1, 1, 1) }
          GradientStop { position: 6 / 6; color: Qt.hsva(0, 1, 1, 1) }
        }

        // Where the hue is on the bar.
        Rectangle {
          x: root.hue * hueBar.width - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: 6
          height: hueBar.height + 6
          radius: 3
          color: Qt.hsva(root.hue, 1, 1, 1)
          border.color: "white"
          border.width: 2
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor

          function pick(mouse) {
            root.hue = root.clamp((mouse.x - 4) / hueBar.width)
            root.picked(root.chosen.toString())
          }

          onPressed: mouse => pick(mouse)
          onPositionChanged: mouse => pick(mouse)
        }
      }

      // The color picked, and its value.
      Row {
        spacing: 10

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 40
          height: 24
          radius: Theme.radiusFor(height)
          color: root.chosen
          border.color: Theme.textColor
          border.width: 1
        }

        ThemedText {
          anchors.verticalCenter: parent.verticalCenter
          text: root.chosen.toString().toUpperCase()
          color: Theme.textColor
        }
      }

      // Picks the color from the screen instead.
      Rectangle {
        width: square.width
        height: 28
        radius: Theme.radiusFor(height)
        color: screenMouse.containsMouse ? Theme.borderColor : "transparent"
        border.color: Theme.outlineColor
        border.width: 1

        ThemedText {
          anchors.centerIn: parent
          width: parent.width - 16
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: "󰈊 " + I18n.tr("colorPicker.screen")
          sizeScale: 0.85
        }

        MouseArea {
          id: screenMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.visible = false
            root.screenPickStarted()
            screenPicker.running = true
          }
        }
      }
    }
  }

  // Picks a color from the screen, and gives it as `picked` (nothing when
  // cancelled).
  Process {
    id: screenPicker
    command: Apps.screenColorPicker

    stdout: StdioCollector {
      id: screenOutput
    }
    stderr: StdioCollector {
      id: screenErrors
    }

    // The color is looked for in both outputs, in case it's printed as a log.
    onExited: code => {
      const found = (screenOutput.text + "\n" + screenErrors.text).match(/#[0-9a-fA-F]{6}/)
      if (found)
        root.picked(found[0].toLowerCase())
      else if (code !== 0 || screenOutput.text.trim().length > 0)
        console.warn("ColorPicker: no color from", Apps.screenColorPicker[0], "(exit code " + code + "):", screenOutput.text.trim(), screenErrors.text.trim())
      root.screenPickFinished()
    }
  }
}
