import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

// Lights tab: keys follow the theme border, your own colours painted key by
// key, or one of the keyboard's built-in effects.
ColumnLayout {
  id: root

  property var svc: null
  property string layoutPath: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color muted: Color.muted
  property string fontFamily: Style.font.family

  spacing: Style.spacing.xl

  property var keys: []
  readonly property var lights: svc ? svc.lights : ({ mode: "theme" })
  readonly property string mode: lights && lights.mode ? lights.mode : "theme"
  // Which page shows. Follows the keyboard, but "My colors" can be opened
  // before anything is painted.
  property string page: mode
  onModeChanged: page = mode

  // My colors is edited here and sent in one go with "Send to keyboard".
  // Until then the map keeps your changes; otherwise it shows what the
  // keyboard has saved.
  property bool dirty: false
  onLightsChanged: syncDraft()
  onKeysChanged: syncDraft()
  function syncDraft() {
    if (root.dirty || root.mode !== "custom" || root.keys.length === 0) return
    if (root.svc && root.svc.lightsBusy) return
    root.startDraft()
  }

  FileView {
    path: root.layoutPath
    onLoaded: {
      try {
        root.keys = JSON.parse(text())
      } catch (ignore) {
        root.keys = []
      }
    }
  }

  // ---- Colours shared by the map ----

  function hexToRgb(hex) {
    var h = String(hex || "#000000").replace("#", "")
    return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)]
  }

  function mix(stops, t) {
    if (!stops || stops.length === 0) return "#ffffff"
    if (stops.length === 1) return stops[0]
    var pos = t * (stops.length - 1)
    var i = Math.min(Math.floor(pos), stops.length - 2)
    var f = pos - i
    var a = hexToRgb(stops[i]), b = hexToRgb(stops[i + 1])
    return Qt.rgba((a[0] + (b[0] - a[0]) * f) / 255, (a[1] + (b[1] - a[1]) * f) / 255, (a[2] + (b[2] - a[2]) * f) / 255, 1)
  }

  // My colors: a working copy, sent after each stroke.
  property var draft: ({})
  property int draftRevision: 0
  property string brush: root.palette.length > 0 ? root.palette[0] : "#ffffff"
  readonly property var palette: svc ? svc.palette : []
  readonly property var basics: ["#ff0000", "#ff7a00", "#ffe100", "#00ff3c", "#00e5ff", "#0050ff", "#8a2bff", "#ff2bd6", "#ffffff"]

  function startDraft() {
    var copy = {}
    var source = root.lights && root.lights.mode === "custom" && root.lights.custom ? root.lights.custom : null
    var stops = root.lights && root.lights.colors ? root.lights.colors : []
    for (var i = 0; i < root.keys.length; i++) {
      var k = root.keys[i]
      if (k.led < 0) continue
      if (source) {
        if (source[String(k.led)]) copy[String(k.led)] = source[String(k.led)]
      } else {
        copy[String(k.led)] = String(root.mix(stops.length ? stops : ["#ffffff"], (k.x + k.w / 2) / 19.5))
      }
    }
    root.draft = copy
    root.draftRevision += 1
  }

  function hexOf(c) {
    function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
    return typeof c === "string" ? c : "#" + h(c.r) + h(c.g) + h(c.b)
  }

  function paint(led) {
    var copy = root.draft
    if (root.brush === "off") delete copy[String(led)]
    else copy[String(led)] = root.brush
    root.draft = copy
    root.draftRevision += 1
    root.dirty = true
  }

  function sendDraft() {
    if (root.svc) root.svc.setLights({ mode: "custom", custom: root.draft })
    root.dirty = false
  }

  function undoDraft() {
    root.dirty = false
    root.startDraft()
  }

  function fillGroup(test) {
    var copy = root.draft
    for (var i = 0; i < root.keys.length; i++) {
      var k = root.keys[i]
      if (k.led < 0 || !test(k)) continue
      if (root.brush === "off") delete copy[String(k.led)]
      else copy[String(k.led)] = root.brush
    }
    root.draft = copy
    root.draftRevision += 1
    root.dirty = true
  }

  readonly property var groups: [
    { label: "All", test: function(k) { return true } },
    { label: "WASD", test: function(k) { return ["W", "A", "S", "D"].indexOf(k.name) >= 0 } },
    { label: "Arrows", test: function(k) { return ["UP", "DOWN", "LEFT", "RIGHT"].indexOf(k.name) >= 0 } },
    { label: "F keys", test: function(k) { return /^F\d+$/.test(k.name) } },
    { label: "Numbers", test: function(k) { return /^NUMROW_/.test(k.name) } },
    { label: "Letters", test: function(k) { return /^[A-Z]$/.test(k.name) } },
    { label: "Number pad", test: function(k) { return /^NUMPAD_|^NUMLOCK$/.test(k.name) } }
  ]

  // ---- Effects ----

  readonly property var effectSetting: root.lights && root.lights.effect ? root.lights.effect
    : { effect: "always-on", speed: 3, brightness: 4, rainbow: false, direction: 0, color: root.palette.length ? root.palette[0] : "#ffffff" }

  function setEffect(changes) {
    var e = {}
    var base = root.effectSetting
    for (var key in base) e[key] = base[key]
    for (var c in changes) e[c] = changes[c]
    if (root.svc) root.svc.setLights({ mode: "effect", effect: e })
  }

  function effectInfo(name) {
    var list = root.svc ? root.svc.effects : []
    for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
    return null
  }

  // ---- Mode buttons ----
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.md

    Button {
      text: "Follow theme"
      bordered: true
      selected: root.page === "theme"
      onClicked: { root.page = "theme"; root.dirty = false; if (root.svc) root.svc.setLights({ mode: "theme" }) }
    }
    Button {
      text: "My colors"
      bordered: true
      selected: root.page === "custom"
      onClicked: {
        root.page = "custom"
        if (root.dirty) return
        root.startDraft()
        // Starting from the theme colours: nothing is sent until you press Send.
        root.dirty = root.mode !== "custom"
      }
    }
    Button {
      text: "Effects"
      bordered: true
      selected: root.page === "effect"
      onClicked: { root.page = "effect"; root.dirty = false; root.setEffect({}) }
    }

    Item { Layout.fillWidth: true }

    Text {
      textFormat: Text.PlainText
      text: root.svc && root.svc.lightsBusy ? "Sending…" : ""
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // ---- The keyboard ----
  KeyboardMap {
    id: map
    Layout.fillWidth: true
    Layout.preferredHeight: width * 6.5 / 19.5
    Layout.maximumHeight: Style.space(330)
    keys: root.keys
    fontFamily: root.fontFamily
    foreground: root.foreground
    paintable: root.page === "custom"
    revision: root.draftRevision + (root.lights && root.lights.colors ? root.lights.colors.length : 0)
    colorFor: function(led, xShare) {
      if (root.page === "custom") {
        var c = root.draft[String(led)]
        return c ? c : "#000000"
      }
      if (root.page === "effect") {
        if (root.effectSetting.rainbow) return Qt.hsva(xShare * 0.85, 1, 1, 1)
        return root.effectSetting.color
      }
      var stops = root.lights && root.lights.colors ? root.lights.colors : []
      return root.mix(stops, xShare)
    }
    onPainted: function(led) { root.paint(led) }
  }

  // ---- Follow theme ----
  Text {
    textFormat: Text.PlainText
    visible: root.page === "theme"
    Layout.fillWidth: true
    text: "The keys use your window border color. Change themes and they change with it."
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.huge
    visible: root.page !== "theme"

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: Style.spacing.md

      // ---- My colors ----
      ColumnLayout {
        visible: root.page === "custom"
        Layout.fillWidth: true
        spacing: Style.spacing.md

        RowLayout {
          spacing: Style.spacing.sm
          Text {
            textFormat: Text.PlainText
            text: "Brush"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Repeater {
            model: root.palette.concat(root.basics)
            delegate: Rectangle {
              required property var modelData
              width: Style.space(22)
              height: width
              radius: width / 4
              color: modelData
              border.width: root.brush === modelData ? 3 : 1
              border.color: root.brush === modelData ? root.foreground : Util.alpha(root.foreground, 0.3)
              MouseArea { anchors.fill: parent; onClicked: root.brush = parent.modelData }
            }
          }
          Button {
            text: "Off"
            bordered: true
            selected: root.brush === "off"
            onClicked: root.brush = "off"
          }
          TextField {
            id: hexField
            Layout.preferredWidth: Style.space(100)
            placeholderText: "#rrggbb"
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            onAccepted: {
              var v = text.trim()
              if (v.charAt(0) !== "#") v = "#" + v
              if (/^#[0-9a-fA-F]{6}$/.test(v)) root.brush = v.toLowerCase()
            }
          }
        }

        RowLayout {
          spacing: Style.spacing.sm
          Text {
            textFormat: Text.PlainText
            text: "Fill"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Repeater {
            model: root.groups
            delegate: Button {
              required property var modelData
              text: modelData.label
              bordered: true
              onClicked: root.fillGroup(modelData.test)
            }
          }
        }

        RowLayout {
          spacing: Style.spacing.md
          Button {
            text: "Send to keyboard"
            bordered: true
            selected: root.dirty
            enabled: root.dirty && !(root.svc && root.svc.lightsBusy)
            onClicked: root.sendDraft()
          }
          Button {
            text: "Undo changes"
            bordered: true
            enabled: root.dirty && root.mode === "custom"
            onClicked: root.undoDraft()
          }
          Text {
            textFormat: Text.PlainText
            text: root.dirty ? "Changes not sent yet." : "Click or drag across keys to paint them, then send."
            color: root.dirty ? root.foreground : root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      // ---- Effects ----
      ColumnLayout {
        visible: root.page === "effect"
        Layout.fillWidth: true
        spacing: Style.spacing.md

        Flow {
          Layout.fillWidth: true
          spacing: Style.spacing.sm
          Repeater {
            model: root.svc ? root.svc.effects : []
            delegate: Button {
              required property var modelData
              text: modelData.label
              bordered: true
              selected: root.effectSetting.effect === modelData.name
              onClicked: root.setEffect({ effect: modelData.name, direction: 0 })
            }
          }
        }

        RowLayout {
          spacing: Style.spacing.xl

          RowLayout {
            spacing: Style.spacing.xs
            Text { text: "Speed"; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            Repeater {
              model: 5
              delegate: Button {
                required property int index
                text: String(index + 1)
                bordered: true
                selected: root.effectSetting.speed === index
                onClicked: root.setEffect({ speed: index })
              }
            }
          }

          RowLayout {
            spacing: Style.spacing.xs
            Text { text: "Brightness"; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            Repeater {
              model: 5
              delegate: Button {
                required property int index
                text: String(index + 1)
                bordered: true
                selected: root.effectSetting.brightness === index
                onClicked: root.setEffect({ brightness: index })
              }
            }
          }

          RowLayout {
            spacing: Style.spacing.xs
            visible: { var info = root.effectInfo(root.effectSetting.effect); return !!(info && info.directions > 0) }
            Text { text: "Direction"; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            Repeater {
              model: { var info = root.effectInfo(root.effectSetting.effect); return info ? info.directions : 0 }
              delegate: Button {
                required property int index
                text: root.effectInfo(root.effectSetting.effect).directions === 4 ? ["→", "←", "↓", "↑"][index] : ["A", "B"][index]
                bordered: true
                selected: root.effectSetting.direction === index
                onClicked: root.setEffect({ direction: index })
              }
            }
          }
        }

        RowLayout {
          spacing: Style.spacing.sm
          Text { text: "Color"; color: root.muted; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          Button {
            text: "Rainbow"
            bordered: true
            selected: !!root.effectSetting.rainbow
            onClicked: root.setEffect({ rainbow: !root.effectSetting.rainbow })
          }
          Repeater {
            model: root.palette.concat(root.basics)
            delegate: Rectangle {
              required property var modelData
              width: Style.space(22)
              height: width
              radius: width / 4
              color: modelData
              border.width: !root.effectSetting.rainbow && root.effectSetting.color === modelData ? 3 : 1
              border.color: !root.effectSetting.rainbow && root.effectSetting.color === modelData ? root.foreground : Util.alpha(root.foreground, 0.3)
              MouseArea { anchors.fill: parent; onClicked: root.setEffect({ color: parent.modelData, rainbow: false }) }
            }
          }
        }
      }
    }

    // Full colour picker for the brush or the effect colour.
    ColumnLayout {
      Layout.alignment: Qt.AlignTop
      spacing: Style.spacing.sm

      ColorPicker {
        id: picker
        foreground: root.foreground
        color: root.page === "effect" ? root.effectSetting.color : (root.brush === "off" ? "#000000" : root.brush)
        onPicked: function(hex) { if (root.page === "custom") root.brush = hex }
        onCommitted: function(hex) {
          if (root.page === "effect") root.setEffect({ color: hex, rainbow: false })
          else root.brush = hex
        }
      }

      RowLayout {
        spacing: Style.spacing.sm
        Rectangle {
          width: Style.space(22)
          height: width
          radius: width / 4
          color: picker.color
          border.width: 1
          border.color: Util.alpha(root.foreground, 0.3)
        }
        Text {
          textFormat: Text.PlainText
          text: root.page === "effect" ? (root.effectSetting.rainbow ? "Rainbow" : root.effectSetting.color) : (root.brush === "off" ? "Off" : root.brush)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }

  Item { Layout.fillHeight: true }
}
