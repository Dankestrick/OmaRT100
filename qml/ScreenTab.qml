import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Screen tab: what the keyboard screen shows now, a drop zone, a link box,
// and the adjust step (move and zoom) before anything is sent.
RowLayout {
  id: root

  property var svc: null
  property bool opened: false
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color muted: Color.muted
  property string fontFamily: Style.font.family
  property int pad: Style.spacing.panelPadding

  signal escapePressed()

  spacing: Style.spacing.huge

  property bool dragHover: false

  // Placement for the adjust step; matches the helper's _fit().
  property real zoom: 1.0
  property real shiftX: 0.0
  property real shiftY: 0.0
  readonly property bool adjusting: !!(svc && svc.pendingPath !== "")
  readonly property bool pendingGif: !!(svc && svc.pendingKind === "gif")
  readonly property bool busy: !!(svc && (svc.sending || svc.fetching))

  function resetPlace() {
    root.zoom = 1.0
    root.shiftX = 0.0
    root.shiftY = 0.0
  }

  function nudge(dx, dy) {
    root.shiftX = Math.max(-1, Math.min(1, root.shiftX + dx))
    root.shiftY = Math.max(-1, Math.min(1, root.shiftY + dy))
  }

  function zoomBy(factor) {
    root.zoom = Math.max(0.2, Math.min(5, root.zoom * factor))
  }

  onAdjustingChanged: if (adjusting) resetPlace()

  // A drop can carry file URLs, a link, or both. Take the first usable one.
  function sourceFromDrop(drop) {
    if (drop.hasUrls && drop.urls.length > 0) {
      var url = drop.urls[0].toString()
      if (url.indexOf("file://") === 0) return decodeURIComponent(url.substring(7))
      if (url.indexOf("http") === 0) return url
    }
    if (drop.hasText) {
      var lines = String(drop.text).split(/\r?\n/)
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("http") === 0) return line
        if (line.indexOf("file://") === 0) return decodeURIComponent(line.substring(7))
      }
    }
    return ""
  }

  // ---- What the screen shows now ----
  ColumnLayout {
    Layout.fillHeight: true
    spacing: Style.spacing.md

    Text {
      textFormat: Text.PlainText
      text: "On the keyboard screen"
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Rectangle {
      id: screenBox
      Layout.preferredHeight: Math.round(Style.space(420))
      Layout.preferredWidth: Math.round(Layout.preferredHeight * 162 / 173)
      color: "black"
      border.color: Util.alpha(root.foreground, 0.25)
      border.width: 1
      clip: true

      readonly property string path: root.svc ? root.svc.preview : ""
      readonly property bool isGif: path.toLowerCase().endsWith(".gif")
      readonly property string url: path ? "file://" + path + "?r=" + (root.svc ? root.svc.previewRevision : 0) : ""

      Image {
        anchors.fill: parent
        visible: !screenBox.isGif && screenBox.url !== ""
        source: visible ? screenBox.url : ""
        cache: false
        fillMode: Image.PreserveAspectFit
      }

      AnimatedImage {
        // GIFs sit top-left at 128x160, like on the keyboard.
        width: Math.round(parent.width * 128 / 162)
        height: Math.round(parent.height * 160 / 173)
        visible: screenBox.isGif
        source: visible ? screenBox.url : ""
        cache: false
        playing: root.opened
        fillMode: Image.PreserveAspectCrop
      }

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: screenBox.url === ""
        text: "Nothing sent yet"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  // ---- Drop zone or adjust step ----
  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Style.spacing.lg

    Rectangle {
      id: stage
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.cornerRadius
      color: root.dragHover ? Util.alpha(root.accent, 0.18) : Util.alpha(root.foreground, 0.04)
      border.width: Math.max(2, Style.space(2))
      border.color: root.dragHover ? root.accent : Util.alpha(root.foreground, root.adjusting ? 0.15 : 0.3)

      Behavior on color { ColorAnimation { duration: 300 } }
      Behavior on border.color { ColorAnimation { duration: 300 } }

      DropArea {
        anchors.fill: parent
        enabled: !root.busy
        onEntered: function(drag) {
          root.dragHover = true
          drag.accept(Qt.CopyAction)
        }
        onExited: root.dragHover = false
        onDropped: function(drop) {
          root.dragHover = false
          var source = root.sourceFromDrop(drop)
          if (source !== "" && root.svc) {
            drop.accept(Qt.CopyAction)
            root.svc.prepare(source)
          }
        }
      }

      // Waiting for a drop, or sending
      ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - root.pad * 2
        visible: !root.adjusting
        spacing: Style.spacing.md

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: !root.svc ? ""
            : root.svc.fetching ? "Getting it ready…"
            : root.svc.sending ? (root.svc.progress >= 0 ? "Sending to the keyboard… " + root.svc.progress + "%" : "Getting it ready…")
            : "Drop a picture or GIF here"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
          wrapMode: Text.Wrap
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          visible: !root.busy
          text: "From your files or straight from a browser. GIPHY links work. You can move and zoom it before it's sent."
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: parent.width * 0.7
          Layout.preferredHeight: Style.space(6)
          visible: !!(root.svc && root.svc.sending && root.svc.progress >= 0)
          radius: height / 2
          color: Util.alpha(root.foreground, 0.12)
          Rectangle {
            width: parent.width * Math.max(0, root.svc ? root.svc.progress : 0) / 100
            height: parent.height
            radius: parent.radius
            color: root.accent
            Behavior on width { NumberAnimation { duration: 300 } }
          }
        }
      }

      // Adjust step
      RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        visible: root.adjusting
        spacing: Style.spacing.huge

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Rectangle {
            id: frame
            // The exact shape that ends up on the keyboard.
            readonly property real aspect: root.pendingGif ? 128 / 160 : 162 / 173
            height: Math.min(parent.height, parent.width / aspect)
            width: height * aspect
            anchors.centerIn: parent
            color: "black"
            clip: true
            border.width: 0

            readonly property real naturalW: root.svc && root.svc.pendingWidth > 0 ? root.svc.pendingWidth : 1
            readonly property real naturalH: root.svc && root.svc.pendingHeight > 0 ? root.svc.pendingHeight : 1
            readonly property real scale: Math.max(width / naturalW, height / naturalH) * root.zoom
            readonly property string url: root.adjusting ? "file://" + root.svc.pendingPath : ""

            Image {
              visible: !root.pendingGif
              source: visible ? frame.url : ""
              cache: false
              smooth: true
              width: frame.naturalW * frame.scale
              height: frame.naturalH * frame.scale
              x: (frame.width - width) / 2 + root.shiftX * frame.width
              y: (frame.height - height) / 2 + root.shiftY * frame.height
            }

            AnimatedImage {
              visible: root.pendingGif
              source: visible ? frame.url : ""
              cache: false
              playing: root.opened && visible
              width: frame.naturalW * frame.scale
              height: frame.naturalH * frame.scale
              x: (frame.width - width) / 2 + root.shiftX * frame.width
              y: (frame.height - height) / 2 + root.shiftY * frame.height
            }

            // Drag to move, scroll to zoom.
            MouseArea {
              anchors.fill: parent
              cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
              property real lastX: 0
              property real lastY: 0
              onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y }
              onPositionChanged: function(mouse) {
                root.nudge((mouse.x - lastX) / frame.width, (mouse.y - lastY) / frame.height)
                lastX = mouse.x
                lastY = mouse.y
              }
              onWheel: function(wheel) { root.zoomBy(wheel.angleDelta.y > 0 ? 1.08 : 1 / 1.08) }
            }
          }

          Rectangle {
            anchors.fill: frame
            color: "transparent"
            border.width: Math.max(2, Style.space(2))
            border.color: root.accent
          }
        }

        ColumnLayout {
          Layout.fillHeight: true
          Layout.preferredWidth: Style.space(220)
          spacing: Style.spacing.lg

          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: root.pendingGif ? "Line up the GIF" : "Line up the picture"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            wrapMode: Text.Wrap
          }

          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: "Drag it, scroll to zoom, or use the buttons."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }

          GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            rowSpacing: Style.spacing.sm
            columnSpacing: Style.spacing.sm

            Item { width: 1; height: 1 }
            Button { text: "▲"; bordered: true; onClicked: root.nudge(0, -0.03) }
            Item { width: 1; height: 1 }
            Button { text: "◀"; bordered: true; onClicked: root.nudge(-0.03, 0) }
            Button { text: "•"; bordered: true; tooltipText: "Center"; onClicked: { root.shiftX = 0; root.shiftY = 0 } }
            Button { text: "▶"; bordered: true; onClicked: root.nudge(0.03, 0) }
            Item { width: 1; height: 1 }
            Button { text: "▼"; bordered: true; onClicked: root.nudge(0, 0.03) }
            Item { width: 1; height: 1 }
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.spacing.sm
            Button { text: "−"; bordered: true; tooltipText: "Zoom out"; onClicked: root.zoomBy(1 / 1.1) }
            Text {
              textFormat: Text.PlainText
              text: Math.round(root.zoom * 100) + "%"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Button { text: "+"; bordered: true; tooltipText: "Zoom in"; onClicked: root.zoomBy(1.1) }
          }

          Button {
            Layout.fillWidth: true
            text: "Reset"
            bordered: true
            onClicked: root.resetPlace()
          }

          Item { Layout.fillHeight: true }

          Button {
            Layout.fillWidth: true
            text: "Send to keyboard"
            bordered: true
            selected: true
            onClicked: if (root.svc) root.svc.sendPending({ zoom: root.zoom, x: root.shiftX, y: root.shiftY })
          }

          Button {
            Layout.fillWidth: true
            text: "Cancel"
            bordered: true
            onClicked: if (root.svc) root.svc.cancelPending()
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.md

      TextField {
        id: linkField
        // Fill the free space but never grow with the text: a long entry
        // scrolls inside the box instead of pushing the row wider.
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: Style.space(160)
        placeholderText: "Paste a link (GIPHY page, or a picture or GIF address)"
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        enabled: !root.busy
        onAccepted: sendLink.clicked()
        Keys.onEscapePressed: root.escapePressed()
      }

      Button {
        id: sendLink
        text: "Open link"
        bordered: true
        enabled: linkField.text.trim() !== "" && !root.busy
        onClicked: {
          if (root.svc) root.svc.prepare(linkField.text)
          linkField.text = ""
        }
      }

      Button {
        text: "Choose file…"
        bordered: true
        enabled: !root.busy
        onClicked: if (root.svc) root.svc.chooseFile()
      }
    }
  }
}
