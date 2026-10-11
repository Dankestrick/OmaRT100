import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The OmaRT100 window: a normal app window, floated and centered by Hyprland
// because its size is fixed. It stacks like any other app, so the screensaver
// covers it, and pictures and GIFs can be dragged in from other windows.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool closingFromHost: false
  property string tab: "screen"
  // A message belongs to the tab it came from.
  onTabChanged: if (svc && !svc.sending) svc.notice = ""

  readonly property var svc: (shell && shell.serviceFor)
    ? shell.serviceFor((manifest && manifest.id) || "io.github.dankestrick.omart100") : null
  readonly property var status: svc ? svc.status : ({})

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property color accent: Color.accent
  property color muted: Color.muted
  property string fontFamily: Style.font.family
  readonly property int pad: Style.spacing.panelPadding

  function localPath(relative) {
    var url = Qt.resolvedUrl(relative).toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return decodeURIComponent(url)
  }

  function open(payloadJson) {
    root.closingFromHost = false
    var monitor = Hyprland.focusedMonitor
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (monitor && Quickshell.screens[i].name === monitor.name && !panel.visible) panel.screen = Quickshell.screens[i]
    root.opened = true
    try {
      var payload = payloadJson ? JSON.parse(payloadJson) : null
      if (payload && ["screen", "lights", "profiles", "macros"].indexOf(payload.tab) >= 0) root.tab = payload.tab
    } catch (ignore) {}
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.closingFromHost = true
    root.opened = false
    root.closingFromHost = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.dankestrick.omart100")
  }

  readonly property string statusLine: {
    if (!root.svc) return "Starting…"
    if (!root.status || root.status.connected === undefined) return "Starting the keyboard helper…"
    if (!root.status.connected) return "Keyboard not found. Plug in the cable and flip the switch to Off."
    var parts = ["Connected by cable"]
    if (root.status.cpu !== null && root.status.cpu !== undefined) parts.push("CPU " + root.status.cpu + "%")
    if (root.status.temp) parts.push(root.status.temp + "°C")
    return parts.join("   ·   ")
  }

  readonly property var tabs: [
    { id: "screen", label: "Screen" },
    { id: "lights", label: "Lights" },
    { id: "profiles", label: "Profiles" },
    { id: "macros", label: "Macros" }
  ]

  FloatingWindow {
    id: panel
    visible: root.opened
    title: "OmaRT100"
    color: root.background
    // A fixed size makes Hyprland float and center it with no window rule.
    property size fixed: Qt.size(Math.round(Style.space(1180)), Math.round(Style.space(720)))
    implicitWidth: fixed.width
    implicitHeight: fixed.height
    minimumSize: fixed
    maximumSize: fixed

    // Closed from Hyprland (SUPER+W): tell the shell so the next toggle opens it.
    onVisibleChanged: {
      if (!visible && root.opened && !root.closingFromHost) root.dismiss()
    }

    // Hyprland draws the window border, so the card is just the background.
    Rectangle {
      id: card
      anchors.fill: parent
      color: root.background

      // Faint OMART100 behind everything, out to the border.
      NameBackdrop {
        anchors.margins: Style.space(2)
        fontFamily: root.fontFamily
        color: root.accent
        // Stronger than the 0.09 default: this card is solid black almost
        // everywhere, and at 0.09 the name only showed inside the drop box.
        strength: 0.16
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.dismiss()

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.pad
          spacing: Style.spacing.xxl

          // Title row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.lg

            Text {
              textFormat: Text.PlainText
              text: "OmaRT100"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Repeater {
              model: root.tabs
              delegate: Button {
                required property var modelData
                text: modelData.label
                bordered: true
                selected: root.tab === modelData.id
                onClicked: root.tab = modelData.id
              }
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignRight
              text: root.statusLine
              color: root.status && root.status.connected ? root.foreground : root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Button {
              text: "Close"
              bordered: true
              onClicked: root.dismiss()
            }
          }

          StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["screen", "lights", "profiles", "macros"].indexOf(root.tab)

            ScreenTab {
              svc: root.svc
              opened: root.opened
              foreground: root.foreground
              accent: root.accent
              muted: root.muted
              fontFamily: root.fontFamily
              pad: root.pad
              onEscapePressed: root.dismiss()
            }

            LightsTab {
              svc: root.svc
              layoutPath: root.localPath("../helpers/rt100-layout.json")
              foreground: root.foreground
              accent: root.accent
              muted: root.muted
              fontFamily: root.fontFamily
            }

            ProfilesTab {
              svc: root.svc
              opened: root.opened && root.tab === "profiles"
              foreground: root.foreground
              accent: root.accent
              muted: root.muted
              fontFamily: root.fontFamily
              onEscapePressed: root.dismiss()
            }

            MacrosTab {
              svc: root.svc
              opened: root.opened && root.tab === "macros"
              layoutPath: root.localPath("../helpers/rt100-layout.json")
              foreground: root.foreground
              accent: root.accent
              muted: root.muted
              fontFamily: root.fontFamily
            }
          }

          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: root.svc ? root.svc.notice : ""
            visible: text !== ""
            color: root.svc && root.svc.noticeIsError ? Color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }
}
