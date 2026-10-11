import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui
import "MacroKeys.js" as MacroKeys

// Macros tab: record or type a macro, pick the key that plays it, and save it
// to the keyboard. The keyboard plays it by itself, so it works on any
// computer and needs nothing running here.
RowLayout {
  id: root

  property var svc: null
  property bool opened: false
  property string layoutPath: ""
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color muted: Color.muted
  property string fontFamily: Style.font.family

  spacing: Style.spacing.xxl

  readonly property bool busy: !!(svc && svc.macroBusy !== "")
  readonly property var macros: svc ? svc.macros : []

  property var keys: []
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

  // ---- The macro being edited ----
  property string editId: ""
  property string name: ""
  property var steps: []
  property string timing: "recorded"
  property string plays: "once"
  property int times: 1
  property var key: null                 // {slot, fn, label}
  property bool keyFn: false
  property bool dirty: false
  property bool recording: false
  property real lastEventTime: 0
  property string confirmDelete: ""
  property int mapRevision: 0
  property var conflict: null            // {key, macro}: a picked key another macro holds

  onOpenedChanged: {
    if (!opened) root.recording = false
    else if (svc) svc.loadKeymap()
  }

  function startNew() {
    root.recording = false
    root.editId = ""
    root.name = ""
    root.steps = []
    root.timing = "recorded"
    root.plays = "once"
    root.times = 1
    root.key = null
    root.keyFn = false
    root.dirty = false
    root.confirmDelete = ""
    root.conflict = null
    root.mapRevision += 1
  }

  function load(macro) {
    root.recording = false
    root.editId = macro.id
    root.name = macro.name
    root.steps = JSON.parse(JSON.stringify(macro.steps || []))
    root.timing = macro.timing || "recorded"
    root.plays = macro.plays || "once"
    root.times = macro.times || 1
    root.key = macro.bound ? { slot: macro.bound.slot, fn: macro.bound.fn, label: macro.bound.label } : null
    root.keyFn = !!(macro.bound && macro.bound.fn)
    root.dirty = false
    root.confirmDelete = ""
    root.conflict = null
    root.mapRevision += 1
  }

  // After a save, keep the saved macro selected and show what the keyboard has.
  Connections {
    target: root.svc
    function onMacrosChanged() {
      var id = root.svc.savedMacroId || root.editId
      for (var i = 0; i < root.macros.length; i++)
        if (root.macros[i].id === id) {
          if (!root.dirty || root.svc.savedMacroId !== "") root.load(root.macros[i])
          root.svc.savedMacroId = ""
          return
        }
      if (root.editId !== "") root.startNew()
    }
  }

  // The keyboard keeps 256 bytes per macro (same math as the helper's
  // encode_macro): 2 for the repeat count, then 2 per step, or 4 when the
  // step waits longer than 127 ms.
  readonly property int maxBytes: 256
  function macroBytes(list) {
    var total = 2
    for (var i = 0; i < list.length; i++) {
      var delay = root.timing === "fast" ? 10 : list[i].delay
      total += delay <= 127 ? 2 : 4
    }
    return total
  }
  readonly property int savedBytes: macroBytes(root.steps)
  // Counts the text box too, so the number moves while you type.
  readonly property int usedBytes: macroBytes(root.steps.concat(MacroKeys.typeSteps(typeField.text, 10)))

  // Text colour for a filled button: dark on light accents (Catppuccin,
  // Hackerman, Tokyo Night), light on dark ones (Crimson Veil).
  function textOn(fill) {
    var c = Qt.color(fill)
    if (c.a < 0.5) return root.foreground
    return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) > 0.55 ? "#111111" : "#f4f4f4"
  }

  function setSteps(list) {
    root.steps = list
    root.dirty = true
  }

  function record(usage, down, label) {
    var now = Date.now()
    var list = root.steps.slice()
    if (list.length > 0 && root.lastEventTime > 0)
      list[list.length - 1].delay = Math.max(1, Math.min(5000, now - root.lastEventTime))
    list.push({ usage: usage, down: down, delay: 10, label: label })
    root.lastEventTime = now
    root.setSteps(list)
  }

  function startRecording() {
    root.recording = true
    root.lastEventTime = 0
    recorder.forceActiveFocus()
  }

  // Keys still held when recording stops get their release added.
  function stopRecording() {
    root.recording = false
    var held = {}
    for (var i = 0; i < root.steps.length; i++) held[root.steps[i].usage] = root.steps[i].down
    var list = root.steps.slice()
    for (var usage in held)
      if (held[usage]) list.push({ usage: Number(usage), down: false, delay: 10, label: MacroKeys.label(Number(usage)) })
    if (list.length !== root.steps.length) root.setSteps(list)
  }

  function removeChip(chip) {
    var list = root.steps.slice()
    list.splice(chip.first, chip.count)
    root.setSteps(list)
  }

  // Full key names, so the two Enters, Ctrls, Shifts and Alts read apart.
  function keyName(k) {
    if (k.name === "RIGHT_ALT") return "AltGr"
    if (/^NUMPAD_/.test(k.name)) return "Num " + k.label
    if (/^LEFT_/.test(k.name)) return "Left " + k.label
    if (/^RIGHT_/.test(k.name) && k.name !== "RIGHT") return "Right " + k.label
    if (k.name === "DIAL") return "Knob press"
    return k.label
  }

  function keyText() {
    if (!root.key) return "Not on a key yet"
    return (root.key.fn ? "Fn + " : "") + root.key.label
  }

  function macroKeyText(macro) {
    if (!macro.bound) return "Not on a key"
    return "On " + (macro.bound.fn ? "Fn + " : "") + macro.bound.label
  }

  // Keys other macros sit on, in the layer being picked.
  function otherMacroOn(slot, fn) {
    for (var i = 0; i < root.macros.length; i++) {
      var b = root.macros[i].bound
      if (b && root.macros[i].id !== root.editId && b.slot === slot && !!b.fn === fn) return root.macros[i]
    }
    return null
  }

  // Take the other macro off the key (the key goes back to normal), then
  // this macro gets it.
  function freeConflict() {
    if (!root.conflict || !root.svc) return
    var other = root.conflict.macro
    var k = root.conflict.key
    root.conflict = null
    root.svc.freeKey({ id: other.id, name: other.name, steps: other.steps, timing: other.timing,
                       plays: other.plays, times: other.times, key: null })
    root.key = { slot: k.slot, fn: root.keyFn, label: root.keyName(k) }
    root.dirty = true
    root.mapRevision += 1
  }

  function usable(k) {
    if (k.name === "FN" || k.slot === undefined) return false
    if (root.keyFn && root.svc && root.svc.fnTaken.indexOf(k.slot) >= 0) return false
    return true
  }

  function save() {
    if (!root.svc) return
    root.recording = false
    root.svc.saveMacro({
      id: root.editId, name: root.name, steps: root.steps, timing: root.timing,
      plays: root.plays, times: root.times, key: root.key
    })
  }

  // ---------------------------------------------------------------------------
  // Left: saved macros
  // ---------------------------------------------------------------------------
  ColumnLayout {
    Layout.preferredWidth: Style.space(250)
    Layout.fillHeight: true
    spacing: Style.spacing.md

    Button {
      Layout.fillWidth: true
      text: "New macro"
      bordered: true
      selected: root.editId === ""
      onClicked: root.startNew()
    }

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentHeight: list.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: list
        width: parent.width
        spacing: Style.spacing.sm

        Repeater {
          model: root.macros
          delegate: Rectangle {
            required property var modelData
            readonly property bool current: root.editId === modelData.id
            width: list.width
            height: Style.space(58)
            radius: Style.cornerRadius
            color: rowMouse.containsMouse ? Util.alpha(root.foreground, 0.09) : Util.alpha(root.foreground, 0.05)
            border.width: current ? Math.max(2, Style.space(2)) : 1
            border.color: current ? root.accent : Util.alpha(root.foreground, 0.2)

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.spacing.lg
              spacing: Style.spacing.xs
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.macroKeyText(modelData)
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.busy
              onClicked: root.load(parent.modelData)
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.fill: parent
        visible: root.macros.length === 0
        text: "No macros yet. Record one on the right, pick its key, and save it to the keyboard."
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
    }

    Text {
      textFormat: Text.PlainText
      Layout.fillWidth: true
      text: "Macros live on the keyboard and play on any computer."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }
  }

  // ---------------------------------------------------------------------------
  // Right: the editor
  // ---------------------------------------------------------------------------
  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Style.spacing.lg

    // Name and how it plays
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.md

      TextField {
        Layout.preferredWidth: Style.space(260)
        placeholderText: "Name this macro"
        text: root.name
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        maximumLength: 40
        enabled: !root.busy
        onTextEdited: { root.name = text; root.dirty = true }
      }

      Item { Layout.preferredWidth: Style.spacing.lg }

      Text {
        textFormat: Text.PlainText
        text: "Plays"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Repeater {
        model: [
          { id: "once", label: "Each press" },
          { id: "held", label: "While held" },
          { id: "toggle", label: "On / off" }
        ]
        delegate: Button {
          required property var modelData
          text: modelData.label
          bordered: true
          background: root.plays === modelData.id ? root.accent : "transparent"
          foreground: root.textOn(background)
          enabled: !root.busy
          onClicked: { root.plays = modelData.id; root.dirty = true }
        }
      }

      NumberField {
        visible: root.plays === "once"
        label: "Times"
        from: 1
        to: 99
        value: root.times
        fontFamily: root.fontFamily
        onModified: function(value) { root.times = value; root.dirty = true }
      }

      Item { Layout.fillWidth: true }

      Text {
        textFormat: Text.PlainText
        // The 2-byte repeat count is left out, so an empty macro reads 0.
        text: "Space used  " + (root.usedBytes - 2) + " / " + (root.maxBytes - 2)
        // Nearly full: the light warning colour. Over: the strong accent.
        color: root.usedBytes > root.maxBytes ? root.accent
             : root.usedBytes > root.maxBytes * 0.85 ? Color.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: root.usedBytes > root.maxBytes * 0.85
      }
    }

    // Steps
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(104)
      radius: Style.cornerRadius
      color: Util.alpha(root.foreground, 0.04)
      border.width: root.recording ? Math.max(2, Style.space(2)) : 1
      border.color: root.recording ? root.accent : Util.alpha(root.foreground, 0.2)

      // Takes the keys while recording. Every key is recorded, Esc included;
      // Stop ends it.
      Item {
        id: recorder
        anchors.fill: parent
        Keys.onPressed: function(event) {
          event.accepted = true
          if (!root.recording || event.isAutoRepeat) return
          var k = MacroKeys.fromScanCode(event.nativeScanCode)
          if (k) root.record(k.usage, true, k.label)
        }
        Keys.onReleased: function(event) {
          event.accepted = true
          if (!root.recording || event.isAutoRepeat) return
          var k = MacroKeys.fromScanCode(event.nativeScanCode)
          if (k) root.record(k.usage, false, k.label)
        }
      }

      Flickable {
        id: stepsFlick
        anchors.fill: parent
        anchors.margins: Style.spacing.md
        contentHeight: chipFlow.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: if (root.recording) contentY = Math.max(0, contentHeight - height)

        Flow {
          id: chipFlow
          width: parent.width
          spacing: Style.spacing.sm

          Repeater {
            model: MacroKeys.chips(root.steps)
            delegate: Rectangle {
              required property var modelData
              width: chipText.implicitWidth + Style.spacing.lg * 2
              height: Style.space(28)
              radius: height / 4
              color: chipMouse.containsMouse ? Util.alpha(Color.urgent, 0.25) : Util.alpha(root.accent, 0.22)
              border.width: 1
              border.color: Util.alpha(root.accent, 0.6)
              Text {
                textFormat: Text.PlainText
                id: chipText
                anchors.centerIn: parent
                text: modelData.text
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.recording && !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeChip(parent.modelData)
              }
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: root.steps.length === 0
        text: root.recording ? "Recording. Press the keys for your macro, then click Stop."
                             : "Click ● Record and press keys, or type text below."
        color: root.recording ? root.foreground : root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    // Record, type, timing
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.md

      // The main control: filled so it's easy to find, red while recording.
      Button {
        id: recordButton
        text: root.recording ? "■  Stop" : "●  Record"
        bordered: true
        background: root.recording ? Color.urgent : root.accent
        foreground: root.textOn(background)
        fontSize: Style.font.title
        horizontalPadding: Style.spacing.xl
        enabled: !root.busy
        onClicked: root.recording ? root.stopRecording() : root.startRecording()

        SequentialAnimation on opacity {
          running: root.recording
          loops: Animation.Infinite
          onRunningChanged: if (!running) recordButton.opacity = 1
          NumberAnimation { to: 0.55; duration: 600; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutQuad }
        }
      }

      Button {
        text: "Clear"
        bordered: true
        enabled: root.steps.length > 0 && !root.recording && !root.busy
        onClicked: root.setSteps([])
      }

      Item { Layout.preferredWidth: Style.spacing.lg }

      TextField {
        id: typeField
        // Fill the free space but never grow with the text: a long entry
        // scrolls inside the box instead of pushing the row wider.
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: Style.space(160)
        placeholderText: "Text to type"
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        enabled: !root.recording && !root.busy
        onAccepted: addText.clicked()
      }

      Button {
        id: addText
        text: "Add text"
        bordered: true
        enabled: typeField.text !== "" && !root.recording && !root.busy && root.usedBytes <= root.maxBytes
        onClicked: {
          root.setSteps(root.steps.concat(MacroKeys.typeSteps(typeField.text, 10)))
          typeField.text = ""
        }
      }

      Item { Layout.preferredWidth: Style.spacing.lg }

      Text {
        textFormat: Text.PlainText
        text: "Timing"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Button {
        text: "As recorded"
        bordered: true
        // Filled rather than "selected": the stock selected look would hide the fill.
        background: root.timing === "recorded" ? root.accent : "transparent"
        foreground: root.textOn(background)
        enabled: !root.busy
        onClicked: { root.timing = "recorded"; root.dirty = true }
      }

      Button {
        text: "Fast"
        bordered: true
        // Filled rather than "selected": the stock selected look would hide the fill.
        background: root.timing === "fast" ? root.accent : "transparent"
        foreground: root.textOn(background)
        enabled: !root.busy
        onClicked: { root.timing = "fast"; root.dirty = true }
      }
    }

    // The key that plays it. Once there are steps and no key yet, the two
    // key buttons fill in like Record and Save, so the step after Stop shows.
    Rectangle {
      id: keyBox
      readonly property bool needKey: !root.recording && root.steps.length > 0 && !root.key
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.cornerRadius
      color: "transparent"

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.spacing.md

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.md

          Text {
            textFormat: Text.PlainText
            text: "Key"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Button {
            text: "Key alone"
            bordered: true
            // The mode you're in is filled, like the timing buttons.
            background: !root.keyFn ? root.accent : "transparent"
            foreground: root.textOn(background)
            enabled: !root.busy
            onClicked: {
              root.keyFn = false
              root.conflict = null
              if (root.key && root.key.fn) root.key = null
              root.mapRevision += 1
            }
          }

          Button {
            text: "Fn + key"
            bordered: true
            background: root.keyFn ? root.accent : "transparent"
            foreground: root.textOn(background)
            enabled: !root.busy
            onClicked: {
              root.keyFn = true
              root.conflict = null
              if (root.key && !root.key.fn) root.key = null
              root.mapRevision += 1
            }
          }

          Text {
            textFormat: Text.PlainText
            Layout.leftMargin: Style.spacing.md
            text: keyBox.needKey ? "Now click a key below." : root.keyText()
            color: keyBox.needKey ? root.accent : (root.key ? root.foreground : root.muted)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: !!root.key
          }

          // Right beside the key name, so it's easy to find.
          Button {
            text: "Take off key"
            bordered: true
            visible: !!root.key
            enabled: !root.busy
            onClicked: { root.key = null; root.dirty = true; root.mapRevision += 1 }
          }

          Item { Layout.fillWidth: true }
        }

        KeyboardMap {
          id: map
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: Style.space(160)
          keys: root.keys
          paintable: !root.busy && !root.recording
          foreground: root.foreground
          fontFamily: root.fontFamily
          revision: root.mapRevision + (root.svc ? root.svc.fnTaken.length + root.macros.length : 0)
          keyUsable: function(k) { return root.usable(k) }
          keyColor: function(k) {
            if (root.key && k.slot === root.key.slot && !!root.key.fn === root.keyFn) return root.accent
            if (k.slot !== undefined && root.otherMacroOn(k.slot, root.keyFn))
              return Qt.rgba(root.accent.r * 0.45, root.accent.g * 0.45, root.accent.b * 0.45, 1)
            return "#26262b"
          }
          onPickedKey: function(k) {
            var other = root.otherMacroOn(k.slot, root.keyFn)
            if (other) {
              root.conflict = { key: k, macro: other }
              return
            }
            root.conflict = null
            root.key = { slot: k.slot, fn: root.keyFn, label: root.keyName(k) }
            root.dirty = true
            root.mapRevision += 1
          }
        }

        // A key that already plays another macro: offer to free it.
        RowLayout {
          Layout.fillWidth: true
          visible: !!root.conflict
          spacing: Style.spacing.md

          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: root.conflict
              ? (root.keyFn ? "Fn + " : "") + root.keyName(root.conflict.key) + " already plays “" + root.conflict.macro.name + "”."
              : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Button {
            text: root.conflict ? "Take it off " + root.conflict.macro.name : ""
            bordered: true
            enabled: !root.busy
            onClicked: root.freeConflict()
          }

          Button {
            text: "Cancel"
            bordered: true
            onClicked: root.conflict = null
          }
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: !root.conflict
          text: root.keyFn
            ? "Fn + key keeps the key's normal job. Dimmed keys already do something with Fn. Dark red keys hold your other macros; click one to free it."
            : "The key types the macro instead of its own letter. Dark red keys hold your other macros; click one to free it."
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }
      }
    }

    // Save
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.md

      Button {
        text: root.svc && root.svc.macroBusy === "saving" ? "Saving…" : "Save to keyboard"
        bordered: true
        background: enabled && !!root.key ? root.accent : Util.alpha(root.foreground, 0.06)
        foreground: root.textOn(background)
        fontSize: Style.font.title
        horizontalPadding: Style.spacing.xl
        enabled: !root.busy && !root.recording && root.name.trim() !== "" && root.steps.length > 0
          && (root.dirty || root.editId === "") && root.savedBytes <= root.maxBytes
        onClicked: root.save()
      }

      Button {
        text: "Undo changes"
        bordered: true
        visible: root.dirty && root.editId !== ""
        enabled: !root.busy
        onClicked: {
          for (var i = 0; i < root.macros.length; i++)
            if (root.macros[i].id === root.editId) root.load(root.macros[i])
        }
      }

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: root.recording ? "Press Stop when you're done."
            : root.steps.length === 0 ? "Record or type something first."
            : root.savedBytes > root.maxBytes ? "Too long for the keyboard: click steps to remove them, or try Fast."
            : root.name.trim() === "" ? "Give it a name to save it."
            : !root.key ? "Pick a key so it plays, or save it without one."
            : root.dirty ? "Changes not saved yet." : ""
        color: Util.alpha(root.foreground, 0.8)
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
      }

      Button {
        visible: root.editId !== ""
        text: root.svc && root.svc.macroBusy === "deleting" ? "Deleting…"
            : (root.confirmDelete === root.editId ? "Sure?" : "Delete macro")
        bordered: true
        enabled: !root.busy
        onClicked: {
          if (root.confirmDelete === root.editId) {
            root.confirmDelete = ""
            if (root.svc) root.svc.deleteMacro(root.editId)
          } else {
            root.confirmDelete = root.editId
          }
        }
      }
    }
  }
}
