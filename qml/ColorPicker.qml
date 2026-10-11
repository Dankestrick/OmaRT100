import QtQuick
import qs.Commons

// A full colour picker: a saturation/brightness square and a hue strip.
// Setting `color` from outside moves the markers; dragging emits `picked`
// while moving and `committed` on release.
Item {
  id: root

  property color color: "#ff0000"
  property color foreground: Color.foreground

  signal picked(string hex)
  signal committed(string hex)

  property real hue: 0
  property real sat: 1
  property real val: 1
  property bool _dragging: false

  implicitWidth: Style.space(260)
  implicitHeight: Style.space(170)

  function hex() {
    var c = Qt.hsva(root.hue, root.sat, root.val, 1)
    function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  onColorChanged: {
    if (root._dragging) return
    var c = root.color
    if (c.hsvHue >= 0) root.hue = c.hsvHue
    root.sat = c.hsvSaturation
    root.val = c.hsvValue
  }

  readonly property real stripWidth: Style.space(22)
  readonly property real gapWidth: Style.space(10)

  // Saturation (left to right) and brightness (top to bottom).
  Rectangle {
    id: square
    width: root.width - root.stripWidth - root.gapWidth
    height: root.height
    radius: Style.space(4)
    clip: true
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: "#ffffff" }
      GradientStop { position: 1; color: Qt.hsva(root.hue, 1, 1, 1) }
    }
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      gradient: Gradient {
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 1; color: "#000000" }
      }
    }
    Rectangle {
      width: Style.space(12)
      height: width
      radius: width / 2
      x: root.sat * square.width - width / 2
      y: (1 - root.val) * square.height - height / 2
      color: "transparent"
      border.width: 2
      border.color: root.val > 0.5 ? "#000000" : "#ffffff"
    }
    MouseArea {
      anchors.fill: parent
      function pick(mx, my) {
        root.sat = Math.max(0, Math.min(1, mx / width))
        root.val = Math.max(0, Math.min(1, 1 - my / height))
        root.picked(root.hex())
      }
      onPressed: function(m) { root._dragging = true; pick(m.x, m.y) }
      onPositionChanged: function(m) { if (pressed) pick(m.x, m.y) }
      onReleased: { root._dragging = false; root.committed(root.hex()) }
    }
  }

  // Hue
  Rectangle {
    id: strip
    x: square.width + root.gapWidth
    width: root.stripWidth
    height: root.height
    radius: Style.space(4)
    gradient: Gradient {
      GradientStop { position: 0.000; color: "#ff0000" }
      GradientStop { position: 0.167; color: "#ffff00" }
      GradientStop { position: 0.333; color: "#00ff00" }
      GradientStop { position: 0.500; color: "#00ffff" }
      GradientStop { position: 0.667; color: "#0000ff" }
      GradientStop { position: 0.833; color: "#ff00ff" }
      GradientStop { position: 1.000; color: "#ff0000" }
    }
    Rectangle {
      width: parent.width + Style.space(4)
      x: -Style.space(2)
      height: Style.space(4)
      y: root.hue * strip.height - height / 2
      color: "transparent"
      border.width: 2
      border.color: root.foreground
    }
    MouseArea {
      anchors.fill: parent
      function pick(my) {
        root.hue = Math.max(0, Math.min(0.999, my / height))
        root.picked(root.hex())
      }
      onPressed: function(m) { root._dragging = true; pick(m.y) }
      onPositionChanged: function(m) { if (pressed) pick(m.y) }
      onReleased: { root._dragging = false; root.committed(root.hex()) }
    }
  }
}
