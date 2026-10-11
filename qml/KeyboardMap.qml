import QtQuick
import qs.Commons

// The RT100 drawn key by key from helpers/rt100-layout.json. Each key shows
// the colour `colorFor(led, x)` returns. With `paintable`, clicking or
// dragging across keys calls `painted(led)` once per key touched, and
// `pickedKey(key)` with the whole layout entry. `keyUsable` and `keyColor`
// let the Macros tab pick keys by slot instead of by light.
Item {
  id: root

  property var keys: []
  property var colorFor: function(led, xShare) { return "#000000" }
  property int revision: 0              // bump to repaint
  property bool paintable: false
  property var keyUsable: null          // function(key) -> bool; default: has a light
  property var keyColor: null           // function(key) -> colour; overrides colorFor
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal painted(int led)
  signal pickedKey(var key)
  signal strokeFinished()

  readonly property real unitsWide: 19.5
  readonly property real unitsHigh: 6.5
  readonly property real unit: Math.min(width / unitsWide, height / unitsHigh)
  readonly property real gap: Math.max(2, unit * 0.08)

  implicitHeight: width * unitsHigh / unitsWide

  Item {
    id: board
    width: root.unit * root.unitsWide
    height: root.unit * root.unitsHigh
    anchors.centerIn: parent

    Repeater {
      model: root.keys
      delegate: Rectangle {
        required property var modelData
        // A key without a light (numpad Enter) stays dark and can't be painted.
        readonly property bool lit: { root.revision; return root.keyUsable ? root.keyUsable(modelData) : modelData.led >= 0 }
        readonly property color fill: {
          root.revision
          if (root.keyColor) return root.keyColor(modelData)
          return lit ? root.colorFor(modelData.led, (modelData.x + modelData.w / 2) / root.unitsWide) : "#000000"
        }
        opacity: lit ? 1 : 0.45
        x: modelData.x * root.unit + root.gap / 2
        y: modelData.y * root.unit + root.gap / 2
        width: modelData.w * root.unit - root.gap
        height: modelData.h * root.unit - root.gap
        radius: Math.max(2, root.unit * 0.12)
        color: Qt.rgba(fill.r * 0.85, fill.g * 0.85, fill.b * 0.85, 1)
        border.width: 1
        border.color: Util.alpha(root.foreground, 0.25)

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          width: parent.width - 4
          horizontalAlignment: Text.AlignHCenter
          text: modelData.label
          elide: Text.ElideRight
          // Dark text on light keys, light text on dark ones.
          color: (parent.fill.r * 0.3 + parent.fill.g * 0.59 + parent.fill.b * 0.11) > 0.55 ? "#111111" : "#f0f0f0"
          font.family: root.fontFamily
          font.pixelSize: Math.max(8, root.unit * 0.26)
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.paintable
      cursorShape: root.paintable ? Qt.CrossCursor : Qt.ArrowCursor
      property string lastName: ""

      function keyAt(mx, my) {
        var ux = mx / root.unit
        var uy = my / root.unit
        for (var i = 0; i < root.keys.length; i++) {
          var k = root.keys[i]
          if (ux >= k.x && ux < k.x + k.w && uy >= k.y && uy < k.y + k.h)
            return (root.keyUsable ? root.keyUsable(k) : k.led >= 0) ? k : null
        }
        return null
      }

      function touch(mx, my) {
        var k = keyAt(mx, my)
        if (k && k.name !== lastName) {
          lastName = k.name
          if (k.led >= 0) root.painted(k.led)
          root.pickedKey(k)
        }
      }

      onPressed: function(mouse) { lastName = ""; touch(mouse.x, mouse.y) }
      onPositionChanged: function(mouse) { if (pressed) touch(mouse.x, mouse.y) }
      onReleased: { lastName = ""; root.strokeFinished() }
    }
  }
}
