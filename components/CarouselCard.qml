import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config

// One entry of a CarouselPanel: a framed card that sizes itself from the
// carousel, grows when centered, and reports clicks. Use it as the root of
// the panel's `delegate` and put the card's content inside; `modelData` and
// `index` are filled in by the carousel.
Item {
  id: root

  required property var modelData
  required property int index

  // Card height as a fraction of its width, and how much it grows while
  // centered (side by side only: stacked, the centered card is the full
  // size and the others shrink).
  property real aspectRatio: 9 / 16
  property real selectedScale: 1.6
  // Frame background.
  property color color: Theme.borderColor
  // Whether the card gets an outline (the centered one highlighted in the
  // accent color). Off for cards whose own content already fills the frame
  // edge to edge, e.g. a wallpaper thumbnail, where a border is just noise.
  property bool bordered: true

  // Attached properties only resolve on the delegate's root item, so grab
  // the view here for use by nested handlers.
  readonly property Item view: PathView.view
  readonly property bool current: root.index === root.view.currentIndex

  // The stacked styles, by name: how far a side card turns away (`turn`,
  // in degrees around its vertical axis, a cover flow's 3D look), leans
  // (`lean`, in degrees per place in the screen's plane, fanned like a hand
  // of cards) and drops (`drop`, a fraction of its width, growing with the
  // square of its place, up to a fifth of it), how much the first neighbors shrink and each
  // further one again (`firstScale`, `scaleStep`), and how much darker each
  // place makes it (`shade`, up to `maxShade`).
  readonly property var styles: ({
    coverflow: { turn: 45, lean: 0, drop: 0, firstScale: 0.75, scaleStep: 0.1, shade: 0.35, maxShade: 0.65 },
    gentle: { turn: 20, lean: 0, drop: 0, firstScale: 0.85, scaleStep: 0.07, shade: 0.15, maxShade: 0.35 },
    fan: { turn: 0, lean: 0, drop: 0, firstScale: 0.8, scaleStep: 0.1, shade: 0.2, maxShade: 0.45 },
    deck: { turn: 0, lean: 6, drop: 0.025, firstScale: 0.85, scaleStep: 0.05, shade: 0.12, maxShade: 0.35 }
  })
  // The current stacked style, or null side by side ("row").
  readonly property var look: root.styles[root.view.style] ?? null
  readonly property bool stacked: root.look !== null

  // The room the path gives each card, and where this one is, in those
  // places from the center (negative on the left), following it smoothly as
  // the carousel moves.
  readonly property real slot: root.view.width / root.view.pathItemCount
  readonly property real place: (root.x + root.width / 2 - root.view.width / 2) / root.slot
  readonly property real distance: Math.abs(root.place)
  // How many places there are on each side of the center.
  readonly property real sideCount: (root.view.pathItemCount - 1) / 2
  // Stacked, how far from the center the first neighbors sit (half under
  // the centered card), and how much further each next one: the outermost
  // ones end near the carousel's edges, so fewer cards spread out and
  // overlap less.
  readonly property real firstOffset: root.width * 0.6
  readonly property real offsetStep: root.sideCount > 1
    ? Math.max(0, root.view.width / 2 - root.width * 0.3 - root.firstOffset) / (root.sideCount - 1)
    : 0

  default property alias content: frame.data
  // The transparent border around the face's texture (see `face`).
  readonly property real faceMargin: 2

  // Emitted when the card is clicked, after it has become the current one.
  signal activated()

  // Stacked, the centered card takes a third of the carousel's width, unless
  // that would make it too tall.
  width: root.stacked
    ? Math.min(root.view.width / 3, root.view.height * 0.85 / root.aspectRatio)
    : root.view.width / root.view.pathItemCount * 0.95
  height: width * root.aspectRatio
  scale: !root.stacked && root.current ? root.selectedScale : 1
  // Stacked, each card behind the nearer ones. Never below 0: the carousel
  // itself would then come first for a click and take it as a drag.
  z: root.stacked ? root.sideCount + 1 - root.distance : (root.current ? 1 : 0)
  // Stacked, a card leaving past the last place on a side fades out.
  opacity: root.stacked ? Math.max(0, Math.min(1, (root.sideCount + 0.5 - root.distance) * 2)) : 1

  // Stacked: each card turned and leaned as its style says, smaller, then
  // moved from its place on the path to its place in the stack (see
  // firstOffset), dropping as it goes for a fanned deck.
  transform: [
    Rotation {
      origin.x: root.width / 2
      origin.y: root.height / 2
      axis { x: 0; y: 1; z: 0 }
      angle: root.stacked ? Math.sign(root.place) * root.look.turn * Math.min(1, root.distance) : 0
    },
    Rotation {
      origin.x: root.width / 2
      origin.y: root.height
      angle: root.stacked ? root.place * root.look.lean : 0
    },
    Scale {
      origin.x: root.width / 2
      origin.y: root.height / 2
      xScale: yScale
      yScale: root.stacked
        ? Math.max(0.35, root.distance <= 1 ? 1 - (1 - root.look.firstScale) * root.distance : root.look.firstScale - root.look.scaleStep * (root.distance - 1))
        : 1
    },
    Translate {
      x: root.stacked
        ? Math.sign(root.place) * (root.firstOffset * Math.min(1, root.distance) + root.offsetStep * Math.max(0, root.distance - 1)) - root.place * root.slot
        : 0
      y: root.stacked ? Math.min(0.2, root.look.drop * root.distance * root.distance) * root.width : 0
    }
  ]

  Behavior on scale {
    NumberAnimation { duration: 150 }
  }

  // A soft shadow under the stacked cards, setting each apart from the one
  // behind it.
  RectangularShadow {
    visible: root.stacked
    anchors.fill: parent
    radius: frame.radius
    offset.y: 12
    blur: 32
    spread: 0
    color: Qt.rgba(0, 0, 0, 0.55)
  }

  // The card's face. Stacked, it is drawn into a texture a little larger
  // than the card, then turned and scaled with it: its edges fall inside
  // the texture, smoothed by its filtering, rather than being drawn jagged
  // as a turned item's are, and the mipmaps keep the shrunken cards from
  // shimmering.
  Item {
    id: face
    anchors.fill: parent
    anchors.margins: -root.faceMargin
    layer.enabled: root.stacked
    layer.smooth: true
    layer.mipmap: true

    // Clips the content to the rounded corners.
    ClippingRectangle {
      id: frame
      anchors.fill: parent
      anchors.margins: root.faceMargin
      radius: Theme.radiusFor(height)
      color: root.color
    }

    // Stacked, the cards away from the center darken, the further the more.
    Rectangle {
      visible: root.stacked
      anchors.fill: frame
      radius: frame.radius
      color: "black"
      opacity: root.stacked ? Math.min(root.look.maxShade, root.look.shade * root.distance) : 0
    }

    // Drawn above the content (a child Image would otherwise cover a border
    // on `frame` itself). The centered card is highlighted with the accent
    // color, and at least 3px so it stands out even when borders are thin or
    // off.
    Rectangle {
      visible: root.bordered
      anchors.fill: frame
      radius: frame.radius
      color: "transparent"
      border.color: root.current ? Theme.accentColor : Theme.outlineColor
      border.width: root.current ? Math.max(3, Theme.borderWidth) : Theme.borderWidth
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      root.view.currentIndex = root.index
      root.activated()
    }
  }
}
