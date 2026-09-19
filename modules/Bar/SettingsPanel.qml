import QtQuick
import Quickshell.Io
import qs.config

// Settings panel, toggled from outside via:
//   quickshell -p . ipc call settings toggle
// Each setting applies as soon as it's changed and is remembered (see
// Settings.qml; the language by I18n). Click or drag a slider, or use the
// keys: Up/Down select a row, Left/Right adjust it (Shift for bigger steps),
// Escape closes.
ModalPanel {
  id: root

  // The rows, top to bottom. Sliders take their range from Settings.limits.
  readonly property var rows: [
    { key: "radius", kind: "slider", label: I18n.tr("settings.radius"), step: 1, format: v => v + " px" },
    { key: "language", kind: "choice", label: I18n.tr("settings.language") },
    { key: "opacity", kind: "slider", label: I18n.tr("settings.opacity"), step: 0.05, format: v => Math.round(v * 100) + " %" },
    { key: "spacing", kind: "slider", label: I18n.tr("settings.spacing"), step: 1, format: v => v + " px" },
    { key: "barHeight", kind: "slider", label: I18n.tr("settings.barHeight"), step: 1, format: v => v + " px" },
    { key: "barMarginTop", kind: "slider", label: I18n.tr("settings.barMarginTop"), step: 1, format: v => v + " px" },
    { key: "barMarginLeft", kind: "slider", label: I18n.tr("settings.barMarginLeft"), step: 5, format: v => v + " px" },
    { key: "barMarginRight", kind: "slider", label: I18n.tr("settings.barMarginRight"), step: 5, format: v => v + " px" },
    { key: "borderWidth", kind: "slider", label: I18n.tr("settings.borderWidth"), step: 1, format: v => v + " px" }
  ]

  // Language choices: follow the system, or one of the supported languages.
  readonly property var languageOptions: [{ value: "auto", text: I18n.tr("settings.language.auto") }]
    .concat(I18n.supported.map(code => ({ value: code, text: I18n.languageNames[code] })))

  property int selected: 0

  maxPanelWidth: 640
  maxPanelHeight: 670
  // Stays readable while the widget opacity is being adjusted.
  panelOpacity: Math.max(0.92, Theme.widgetOpacity)

  visible: SettingsPanelState.visible
  onCloseRequested: SettingsPanelState.visible = false
  onOpened: root.selected = 0

  IpcHandler {
    target: "settings"

    function toggle(): void {
      SettingsPanelState.toggle()
    }

    // Sets one setting by name (radius, opacity, spacing, barHeight,
    // barMarginTop, barMarginLeft, barMarginRight, borderWidth); out-of-range values are
    // clamped.
    function set(key: string, value: real): void {
      Settings.set(key, value)
    }

    function get(key: string): real {
      return Settings.get(key)
    }

    // Puts every setting, and the language, back to its default.
    function reset(): void {
      root.resetAll()
    }
  }

  function resetAll() {
    Settings.reset()
    I18n.select("auto")
  }

  // Moves the selected row's value one step (or `steps` of them) up or down.
  function adjust(direction, steps) {
    const row = root.rows[root.selected]
    if (row.kind === "slider") {
      Settings.set(row.key, Settings.get(row.key) + direction * row.step * steps)
    } else {
      const values = root.languageOptions.map(option => option.value)
      const next = (values.indexOf(I18n.setting) + direction + values.length) % values.length
      I18n.select(values[next])
    }
  }

  onKeyPressed: event => {
    const big = (event.modifiers & Qt.ShiftModifier) !== 0
    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
      root.selected = Math.min(root.rows.length - 1, root.selected + 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
      root.selected = Math.max(0, root.selected - 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Left) {
      root.adjust(-1, big ? 5 : 1)
      event.accepted = true
    } else if (event.key === Qt.Key_Right) {
      root.adjust(1, big ? 5 : 1)
      event.accepted = true
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 20
    spacing: 10

    Item {
      width: parent.width
      height: resetButton.implicitHeight

      ThemedText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr("settings.title")
        sizeScale: 1.2
      }

      PowerMenuOption {
        id: resetButton
        anchors.right: parent.right
        label: I18n.tr("settings.reset")
        onClicked: root.resetAll()
      }
    }

    Column {
      width: parent.width
      spacing: 6

      Repeater {
        model: root.rows

        Item {
          id: row

          required property var modelData
          required property int index

          width: parent.width
          height: 54

          SettingSlider {
            visible: row.modelData.kind === "slider"
            anchors.fill: parent
            label: row.modelData.label
            from: row.modelData.kind === "slider" ? Settings.limits[row.modelData.key][0] : 0
            to: row.modelData.kind === "slider" ? Settings.limits[row.modelData.key][1] : 1
            stepSize: row.modelData.step ?? 1
            value: row.modelData.kind === "slider" ? Settings.get(row.modelData.key) : 0
            valueText: row.modelData.kind === "slider" ? row.modelData.format(Settings.get(row.modelData.key)) : ""
            selected: root.selected === row.index
            onActivated: root.selected = row.index
            onMoved: value => Settings.set(row.modelData.key, value)
          }

          ChoiceRow {
            visible: row.modelData.kind === "choice"
            anchors.fill: parent
            label: row.modelData.label
            options: root.languageOptions
            current: I18n.setting
            selected: root.selected === row.index
            onActivated: root.selected = row.index
            onChosen: value => I18n.select(value)
          }
        }
      }
    }

    ThemedText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: I18n.tr("settings.hint")
      opacity: 0.5
      sizeScale: 0.65
    }
  }
}
