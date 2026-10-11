import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Profiles tab: save the lights and the screen together, switch with one click.
ColumnLayout {
  id: root

  property var svc: null
  property bool opened: false
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color muted: Color.muted
  property string fontFamily: Style.font.family

  signal escapePressed()

  spacing: Style.spacing.xl

  readonly property bool busy: !!(svc && (svc.profileBusy !== "" || svc.sending))
  property string confirmDelete: ""

  onOpenedChanged: if (opened && svc) svc.refreshProfiles()

  function lightsText(lights) {
    if (!lights || lights.mode === "theme") return "Keys follow the theme"
    if (lights.mode === "custom") return "My colors"
    if (lights.mode === "effect" && lights.effect) {
      var list = root.svc ? root.svc.effects : []
      for (var i = 0; i < list.length; i++)
        if (list[i].name === lights.effect.effect) return "Effect: " + list[i].label
      return "Effect"
    }
    return ""
  }

  function swatches(lights) {
    if (!lights || lights.mode === "theme") return []
    if (lights.mode === "custom") {
      var seen = []
      for (var led in lights.custom) {
        var c = lights.custom[led]
        if (seen.indexOf(c) < 0) seen.push(c)
        if (seen.length >= 6) break
      }
      return seen
    }
    if (lights.mode === "effect" && lights.effect && !lights.effect.rainbow) return [lights.effect.color]
    return []
  }

  // ---- Save ----
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.md

    TextField {
      id: nameField
      Layout.preferredWidth: Style.space(320)
      placeholderText: "Name for this setup"
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      maximumLength: 40
      enabled: !root.busy
      onAccepted: saveButton.clicked()
      Keys.onEscapePressed: root.escapePressed()
    }

    Button {
      id: saveButton
      text: "Save current as profile"
      bordered: true
      enabled: nameField.text.trim() !== "" && !root.busy
      onClicked: {
        if (root.svc) root.svc.saveProfile(nameField.text)
        nameField.text = ""
      }
    }

    Text {
      textFormat: Text.PlainText
      Layout.fillWidth: true
      text: "Saves the lights and what's on the keyboard screen, with its position."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }
  }

  // ---- Saved profiles ----
  Flickable {
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentHeight: grid.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Flow {
      id: grid
      width: parent.width
      spacing: Style.spacing.xl

      Repeater {
        model: root.svc ? root.svc.profiles : []

        delegate: Rectangle {
          id: card
          required property var modelData
          readonly property bool applying: root.svc && root.svc.applyingId === modelData.id
          width: Style.space(250)
          height: Style.space(330)
          radius: Style.cornerRadius
          color: Util.alpha(root.foreground, 0.05)
          border.width: modelData.active ? Math.max(2, Style.space(2)) : 1
          border.color: modelData.active ? root.accent : Util.alpha(root.foreground, 0.2)

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.spacing.lg
            spacing: Style.spacing.md

            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              Layout.preferredHeight: Style.space(170)
              Layout.preferredWidth: Math.round(Layout.preferredHeight * 162 / 173)
              color: "black"
              border.width: 1
              border.color: Util.alpha(root.foreground, 0.2)
              clip: true

              readonly property string path: card.modelData.preview || ""
              readonly property bool isGif: path.toLowerCase().endsWith(".gif")

              Image {
                anchors.fill: parent
                visible: parent.path !== "" && !parent.isGif
                source: visible ? "file://" + parent.path : ""
                cache: false
                fillMode: Image.PreserveAspectFit
              }
              AnimatedImage {
                width: Math.round(parent.width * 128 / 162)
                height: Math.round(parent.height * 160 / 173)
                visible: parent.isGif
                source: visible ? "file://" + parent.path : ""
                cache: false
                playing: root.opened
                fillMode: Image.PreserveAspectCrop
              }
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: parent.path === ""
                text: "No picture"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: card.modelData.name
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            RowLayout {
              spacing: Style.spacing.xs
              Repeater {
                model: root.swatches(card.modelData.lights)
                delegate: Rectangle {
                  required property var modelData
                  width: Style.space(14)
                  height: width
                  radius: width / 4
                  color: modelData
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.3)
                }
              }
              Text {
                textFormat: Text.PlainText
                text: root.lightsText(card.modelData.lights)
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.sm

              Button {
                Layout.fillWidth: true
                text: card.applying
                  ? (root.svc && root.svc.progress >= 0 ? "Sending " + root.svc.progress + "%" : "Applying…")
                  : (card.modelData.active ? "Applied" : "Apply")
                bordered: true
                selected: !!card.modelData.active
                enabled: !root.busy
                onClicked: if (root.svc) root.svc.applyProfile(card.modelData.id)
              }

              Button {
                text: root.confirmDelete === card.modelData.id ? "Sure?" : "Delete"
                bordered: true
                enabled: !root.busy
                onClicked: {
                  if (root.confirmDelete === card.modelData.id) {
                    root.confirmDelete = ""
                    if (root.svc) root.svc.deleteProfile(card.modelData.id)
                  } else {
                    root.confirmDelete = card.modelData.id
                  }
                }
              }
            }
          }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      visible: !root.svc || root.svc.profiles.length === 0
      text: "No profiles yet. Set up the lights and the screen the way you like, then save it here."
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }
}
