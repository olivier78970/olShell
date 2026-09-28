import QtQuick
import Quickshell.Widgets
import qs.config

// An app with an opacity of its own (or all the windows, their general one),
// on one line in the settings: its icon and name, then two short sliders,
// its opacity when focused and when not, each with its value and a link
// button, and a button taking it out of the list (`removed`). Dragging or
// clicking a slider emits `moved` with "active" or "inactive" and the new
// value, on the step.
//
// A link button makes its value follow another one (`activeSame`,
// `inactiveSame`; the slider then shows that value, dimmed, and can't be
// moved): pressing it emits `sameToggled` with its field, and hovering it
// shows `sameText`, what it follows.
//
// When the row is selected, `focusIndex` marks what the keyboard is on: 0
// the focused slider, 1 its link, 2 the other slider, 3 its link, 4 the
// remove button (the owner moves it and adjusts the sliders, see
// SettingsPanel's keys).
Item {
  id: root

  property string name: ""
  // The app's icon (a file URL or a theme icon's path), "" for none, and the
  // glyph shown without one ("" for none either: the name then starts the
  // line).
  property string icon: ""
  property string glyph: "󰀻"
  // Whether it has the remove button: not for all the windows at once (see
  // SettingsPanel), whose sliders then go to the end of the line.
  property bool removable: true
  property real active: 1
  property real inactive: 1
  property bool activeSame: false
  property bool inactiveSame: false
  property string sameText: ""
  property real from: 0.1
  property real to: 1
  property real step: 0.05
  property bool selected: false
  property int focusIndex: -1

  signal moved(string field, real value)
  signal sameToggled(string field)
  signal removed()
  signal activated()

  // The least it needs: the name at some width, both sliders and the button.
  implicitWidth: 12 + 22 + 10 + 140 + 16 + 2 * sliders.slotWidth + 16 + 12 + 26 + 12
  implicitHeight: 44

  // `raw` (anywhere between from and to) rounded to the nearest step.
  function snap(raw) {
    const snapped = root.from + Math.round((raw - root.from) / root.step) * root.step
    return Math.max(root.from, Math.min(root.to, Math.round(snapped * 100) / 100))
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusFor(height)
    color: root.selected ? Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.14) : "transparent"
    border.color: root.selected ? Theme.accentColor : "transparent"
    border.width: 1
  }

  // Pressing the row anywhere selects it.
  MouseArea {
    anchors.fill: parent
    onPressed: root.activated()
  }

  IconImage {
    id: appIcon
    anchors.left: parent.left
    anchors.leftMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 22
    height: 22
    source: root.icon
    visible: root.icon !== "" && status !== Image.Error
  }

  // The glyph, for an app without an icon (the generic one is the
  // launcher's).
  ThemedText {
    visible: !appIcon.visible
    anchors.centerIn: appIcon
    text: root.glyph
  }

  // The name: after the icon, or at the start without one (nor a glyph).
  ThemedText {
    anchors.left: root.icon === "" && root.glyph === "" ? parent.left : appIcon.right
    anchors.leftMargin: root.icon === "" && root.glyph === "" ? 12 : 10
    anchors.right: sliders.left
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: root.name
    elide: Text.ElideRight
  }

  // The width of the captions before the sliders: the longer of the two, so
  // both sliders line up, whatever the language.
  TextMetrics {
    id: activeCaption
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize() * 0.8
    text: I18n.tr("settings.appOpacity.active")
  }

  TextMetrics {
    id: inactiveCaption
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize() * 0.8
    text: I18n.tr("settings.appOpacity.inactive")
  }

  Row {
    id: sliders

    readonly property real captionWidth: Math.ceil(Math.max(activeCaption.advanceWidth, inactiveCaption.advanceWidth)) + 8
    // The room each slider takes: its caption, its track, its value and its
    // link button.
    readonly property real slotWidth: sliders.captionWidth + 90 + 8 + 50 + 8 + 30

    anchors.right: root.removable ? removeButton.left : parent.right
    anchors.rightMargin: root.removable ? 16 : 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 16

    Repeater {
      model: [
        { field: "active", caption: I18n.tr("settings.appOpacity.active"), value: root.active, same: root.activeSame },
        { field: "inactive", caption: I18n.tr("settings.appOpacity.inactive"), value: root.inactive, same: root.inactiveSame }
      ]

      Item {
        id: slot

        required property var modelData
        required property int index
        readonly property real fraction: (slot.modelData.value - root.from) / (root.to - root.from)
        // Its slider's and its link's places in focusIndex.
        readonly property int sliderFocus: slot.index * 2
        readonly property int linkFocus: slot.index * 2 + 1

        width: sliders.slotWidth
        height: 28

        // The caption, the slider and the value, dimmed while the value
        // follows another.
        Item {
          anchors.left: parent.left
          anchors.right: link.left
          anchors.rightMargin: 8
          height: parent.height
          opacity: slot.modelData.same ? 0.45 : 1

          ThemedText {
            id: caption
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: sliders.captionWidth
            text: slot.modelData.caption
            sizeScale: 0.8
            opacity: 0.7
          }

          // The track, inset by half the knob so it stays inside at both
          // ends, outlined while the keyboard is on it.
          Rectangle {
            anchors.fill: track
            anchors.margins: -6
            radius: Theme.radiusFor(height)
            color: "transparent"
            border.color: Theme.textColor
            border.width: root.selected && root.focusIndex === slot.sliderFocus ? 1 : 0
          }

          Rectangle {
            id: track
            anchors.left: caption.right
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 90 - 14
            height: 6
            radius: Theme.radiusFor(height)
            color: Theme.borderColor

            Rectangle {
              width: track.width * slot.fraction
              height: parent.height
              radius: Theme.radiusFor(height)
              color: Theme.accentColor
            }

            Rectangle {
              x: track.width * slot.fraction - width / 2
              anchors.verticalCenter: parent.verticalCenter
              width: 14
              height: 14
              radius: 7
              color: Theme.accentColor
            }

            // Taller than the track, so it's easy to grab.
            MouseArea {
              anchors.fill: parent
              anchors.topMargin: -11
              anchors.bottomMargin: -11
              anchors.leftMargin: -7
              anchors.rightMargin: -7
              enabled: !slot.modelData.same
              cursorShape: Qt.PointingHandCursor
              preventStealing: true

              function place(mouseX) {
                const raw = root.from + (mouseX - 7) / track.width * (root.to - root.from)
                const value = root.snap(raw)
                if (value !== slot.modelData.value) root.moved(slot.modelData.field, value)
              }

              onPressed: mouse => {
                root.activated()
                place(mouse.x)
              }
              onPositionChanged: mouse => place(mouse.x)
            }
          }

          ThemedText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            horizontalAlignment: Text.AlignRight
            text: Math.round(slot.modelData.value * 100) + " %"
            color: Theme.accentColor
          }
        }

        // The link button, outlined while the keyboard is on it; hovered,
        // what it follows shows above it.
        SameButton {
          id: link
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          on: slot.modelData.same
          onToggled: {
            root.activated()
            root.sameToggled(slot.modelData.field)
          }

          Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radiusFor(height)
            color: "transparent"
            border.color: Theme.textColor
            border.width: root.selected && root.focusIndex === slot.linkFocus ? 1 : 0
          }

          Rectangle {
            visible: link.hovered && root.sameText !== ""
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.right: parent.right
            width: tip.implicitWidth + 16
            height: tip.implicitHeight + 8
            radius: Theme.radiusFor(height)
            color: Theme.pillColor
            border.color: Theme.outlineColor
            border.width: 1
            z: 10

            ThemedText {
              id: tip
              anchors.centerIn: parent
              text: root.sameText
              sizeScale: 0.85
            }
          }
        }
      }
    }
  }

  // The remove button.
  Rectangle {
    id: removeButton
    visible: root.removable
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    width: 26
    height: 26
    radius: Theme.radiusFor(height)
    color: removeMouse.containsMouse ? Theme.borderColor : "transparent"
    border.color: root.selected && root.focusIndex === 4 ? Theme.textColor : Theme.outlineColor
    border.width: root.selected && root.focusIndex === 4 ? 2 : 1

    ThemedText {
      anchors.centerIn: parent
      text: "󰆴"
      sizeScale: 0.9
    }

    MouseArea {
      id: removeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.activated()
        root.removed()
      }
    }
  }
}
