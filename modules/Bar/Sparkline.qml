import QtQuick
import qs.config

// A small area chart of the most recent samples in `values` (oldest first),
// right-aligned so a filling history grows in from the right. The scale is
// `maxValue`, or, when that is 0, the largest sample (but never less than
// `minMax`, so a quiet line stays flat instead of being blown up).
Item {
  id: root

  property var values: []
  property int slots: 60
  property real maxValue: 0
  property real minMax: 1
  property color color: Theme.accentColor

  implicitHeight: 32

  onValuesChanged: canvas.requestPaint()
  onColorChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    renderTarget: Canvas.Image

    onPaint: {
      const ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      const values = root.values
      if (values.length < 2) return

      const top = root.maxValue > 0 ? root.maxValue : Math.max(root.minMax, Math.max.apply(null, values))
      const step = width / (root.slots - 1)
      const pad = 2
      const x = i => width - (values.length - 1 - i) * step
      const y = v => height - pad - Math.min(1, v / top) * (height - pad * 2)

      ctx.beginPath()
      ctx.moveTo(x(0), y(values[0]))
      for (let i = 1; i < values.length; i++) ctx.lineTo(x(i), y(values[i]))

      // Line
      ctx.lineWidth = 1.5
      ctx.lineJoin = "round"
      ctx.strokeStyle = root.color
      ctx.stroke()

      // Area under it, fading out downward
      ctx.lineTo(x(values.length - 1), height)
      ctx.lineTo(x(0), height)
      ctx.closePath()
      const fill = ctx.createLinearGradient(0, 0, 0, height)
      fill.addColorStop(0, Qt.rgba(root.color.r, root.color.g, root.color.b, 0.35))
      fill.addColorStop(1, Qt.rgba(root.color.r, root.color.g, root.color.b, 0))
      ctx.fillStyle = fill
      ctx.fill()
    }
  }
}
