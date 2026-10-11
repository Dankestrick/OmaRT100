import QtQuick
import Quickshell
import Quickshell.Io

// Headless half of OmaRT100. One instance for the whole shell: it starts the
// helper that owns the keyboard and keeps a copy of its status for the window.
//
//   helpers/omart100ctl daemon    CPU + temperature to the screen, key lights
//                                 on the theme border colour, queued uploads
//
// The daemon ends with the shell (setpriv --pdeathsig). Every action is the
// same CLI with an argument list; nothing goes through a shell.
Item {
  id: root

  property var shell: null
  property var manifest: null

  function fileUrl(relative) {
    var url = Qt.resolvedUrl(relative).toString()
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return decodeURIComponent(url)
  }

  readonly property string cli: fileUrl("../helpers/omart100ctl")

  function ctl(seconds, args) {
    return ["timeout", "-k", "5", String(seconds), root.cli].concat(args)
  }

  property var status: ({})
  readonly property bool connected: !!(status && status.connected)
  readonly property int progress: status && status.progress !== null && status.progress !== undefined ? Number(status.progress) : -1
  property bool sending: false
  property string sendingWhat: ""
  property string notice: ""
  property bool noticeIsError: false
  property string preview: ""
  property int previewRevision: 0

  // The adjust step: a picture or GIF waiting for Send.
  property string pendingPath: ""
  property string pendingKind: ""
  property int pendingWidth: 0
  property int pendingHeight: 0
  property bool fetching: false

  readonly property var lights: status && status.keys ? status.keys : ({ mode: "theme" })
  readonly property var palette: status && status.palette ? status.palette : []
  property var effects: []
  property bool lightsBusy: false

  // ---------------------------------------------------------------------------
  // Daemon
  // ---------------------------------------------------------------------------

  Process {
    id: daemonProcess
    command: ["setpriv", "--pdeathsig", "TERM", root.cli, "daemon"]
    running: true
    stdout: SplitParser { onRead: function(line) {} }
    stderr: SplitParser { onRead: function(line) {} }
    onExited: daemonRestart.restart()
  }

  Timer {
    id: daemonRestart
    interval: 5000
    onTriggered: daemonProcess.running = true
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  Process {
    id: statusProcess
    command: root.ctl(5, ["status"])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.status = JSON.parse(String(text).trim() || "{}")
        } catch (ignore) {
          root.status = ({})
        }
        if (root.preview === "" && root.status.preview) {
          root.preview = String(root.status.preview)
          root.previewRevision += 1
        }
      }
    }
  }

  Timer {
    // Quick while the window shows an upload's progress, slow otherwise.
    interval: root.sending ? 500 : 3000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }

  // ---------------------------------------------------------------------------
  // Pictures and GIFs
  // ---------------------------------------------------------------------------

  Process {
    id: showProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishShow(text)
    }
    stderr: SplitParser { onRead: function(line) {} }
    onExited: function(code) {
      if (root.sending) root.finishShow("")
    }
  }

  function show(source, place) {
    var value = String(source || "").trim()
    if (value === "" || showProcess.running) return
    root.notice = ""
    root.noticeIsError = false
    root.sending = true
    root.sendingWhat = value.indexOf("http") === 0 ? "link" : "file"
    showProcess.command = root.ctl(900, ["show", value, JSON.stringify(place || {})])
    showProcess.running = true
  }

  // A drop, a pick or a link lands here first, then waits for Send.
  Process {
    id: fetchProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.fetching = false
        var reply = null
        try {
          reply = JSON.parse(String(text).trim())
        } catch (ignore) {}
        if (reply && reply.ok) {
          root.pendingPath = String(reply.path)
          root.pendingKind = String(reply.kind)
          root.pendingWidth = Number(reply.width) || 0
          root.pendingHeight = Number(reply.height) || 0
        } else {
          root.notice = reply && reply.error ? String(reply.error) : "Couldn't open that."
          root.noticeIsError = true
        }
      }
    }
    stderr: SplitParser { onRead: function(line) {} }
    onExited: root.fetching = false
  }

  function prepare(source) {
    var value = String(source || "").trim()
    if (value === "" || fetchProcess.running || root.sending) return
    root.notice = ""
    root.noticeIsError = false
    root.fetching = true
    fetchProcess.command = root.ctl(60, ["fetch", value])
    fetchProcess.running = true
  }

  function sendPending(place) {
    if (root.pendingPath === "") return
    var path = root.pendingPath
    root.pendingPath = ""
    root.show(path, place)
  }

  function cancelPending() {
    root.pendingPath = ""
  }

  // ---------------------------------------------------------------------------
  // Lights
  // ---------------------------------------------------------------------------

  Process {
    id: effectsProcess
    command: root.ctl(10, ["effects"])
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.effects = JSON.parse(String(text).trim()).effects || []
        } catch (ignore) {}
      }
    }
  }

  property var queuedLights: null

  Process {
    id: lightsProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var reply = null
        try {
          reply = JSON.parse(String(text).trim())
        } catch (ignore) {}
        if (reply && !reply.ok) {
          root.notice = String(reply.error || "The lights didn't change.")
          root.noticeIsError = true
        }
      }
    }
    stderr: SplitParser { onRead: function(line) {} }
    onExited: {
      root.lightsBusy = false
      if (!statusProcess.running) statusProcess.running = true
      if (root.queuedLights) {
        var next = root.queuedLights
        root.queuedLights = null
        root.setLights(next)
      }
    }
  }

  // Painting sends often; only the newest setting waits behind a running one.
  function setLights(lights) {
    if (lightsProcess.running) {
      root.queuedLights = lights
      return
    }
    root.lightsBusy = true
    var args = ["lights", lights.mode]
    if (lights.mode === "custom") args.push(JSON.stringify(lights.custom || {}))
    if (lights.mode === "effect") args.push(JSON.stringify(lights.effect || {}))
    lightsProcess.command = root.ctl(30, args)
    lightsProcess.running = true
  }

  function finishShow(output) {
    if (!root.sending) return
    root.sending = false
    var reply = null
    try {
      reply = JSON.parse(String(output).trim())
    } catch (ignore) {}
    if (reply && reply.ok) {
      root.preview = String(reply.preview || "")
      root.previewRevision += 1
      root.notice = reply.kind === "gif" ? "GIF is on the keyboard." : "Picture is on the keyboard."
      root.refreshProfiles()
      root.noticeIsError = false
    } else {
      root.notice = reply && reply.error ? String(reply.error) : "That upload didn't finish."
      root.noticeIsError = true
    }
  }

  // Choose file: zenity runs here so it keeps going if the window closes.
  Process {
    id: pickProcess
    command: ["zenity", "--file-selection", "--title=Picture or GIF for the RT100",
              "--file-filter=Pictures and GIFs | *.gif *.png *.jpg *.jpeg *.webp *.bmp",
              "--file-filter=All files | *"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text).trim()
        if (path !== "") root.prepare(path)
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  property var profiles: []
  property string profileBusy: ""        // "saving", "applying", "deleting"
  property string applyingId: ""

  Process {
    id: profilesProcess
    command: root.ctl(10, ["profiles"])
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.profiles = JSON.parse(String(text).trim()).profiles || []
        } catch (ignore) {}
      }
    }
  }

  function refreshProfiles() {
    if (!profilesProcess.running) profilesProcess.running = true
  }

  Process {
    id: profileProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var reply = null
        try {
          reply = JSON.parse(String(text).trim())
        } catch (ignore) {}
        if (reply && reply.ok) {
          if (root.profileBusy === "saving") root.notice = "Profile saved."
          else if (root.profileBusy === "applying") root.notice = "Profile applied."
          else root.notice = ""
          root.noticeIsError = false
        } else {
          root.notice = reply && reply.error ? String(reply.error) : "That didn't work."
          root.noticeIsError = true
        }
        if (root.profileBusy === "applying" && reply && reply.ok) {
          root.preview = ""
          root.previewRevision += 1
        }
      }
    }
    stderr: SplitParser { onRead: function(line) {} }
    onExited: {
      root.profileBusy = ""
      root.applyingId = ""
      root.sending = false
      root.refreshProfiles()
      if (!statusProcess.running) statusProcess.running = true
    }
  }

  function runProfile(kind, args) {
    if (profileProcess.running || root.sending) return
    root.notice = ""
    root.profileBusy = kind
    profileProcess.command = root.ctl(900, args)
    profileProcess.running = true
  }

  function saveProfile(name) {
    var value = String(name || "").trim()
    if (value !== "") runProfile("saving", ["profile", "save", value])
  }

  function applyProfile(id) {
    root.applyingId = id
    runProfile("applying", ["profile", "apply", id])
    root.sending = true                   // quick status polls for the upload's progress
  }

  function deleteProfile(id) {
    runProfile("deleting", ["profile", "delete", id])
  }

  function chooseFile() {
    if (!pickProcess.running) pickProcess.running = true
  }

  // ---------------------------------------------------------------------------
  // Macros: saved on the keyboard, so they play anywhere it's plugged in
  // ---------------------------------------------------------------------------

  property var macros: []
  property var fnTaken: []               // Fn + key slots the keyboard already uses
  property string macroBusy: ""          // "saving", "freeing", "deleting"
  property string savedMacroId: ""       // set after a save, so the tab can select it

  Process {
    id: macrosProcess
    command: root.ctl(10, ["macros"])
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.macros = JSON.parse(String(text).trim()).macros || []
        } catch (ignore) {}
      }
    }
  }

  Process {
    id: keymapProcess
    command: root.ctl(40, ["keymap"])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var reply = JSON.parse(String(text).trim())
          if (reply.ok) root.fnTaken = reply.fnTaken || []
        } catch (ignore) {}
      }
    }
    stderr: SplitParser { onRead: function(line) {} }
  }

  function loadKeymap() {
    if (!keymapProcess.running) keymapProcess.running = true
  }

  // A macro goes to the helper on stdin, never on the command line: recorded
  // keys can be typed text.
  Process {
    id: macroProcess
    property string payload: ""
    stdinEnabled: true
    onStarted: {
      if (payload !== "") write(payload + "\n")
      payload = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var reply = null
        try {
          reply = JSON.parse(String(text).trim())
        } catch (ignore) {}
        if (reply && reply.ok) {
          root.notice = root.macroBusy === "saving" ? "Macro saved to the keyboard."
            : root.macroBusy === "freeing" ? "Key freed. Save to put this macro on it."
            : "Macro deleted, key put back."
          root.noticeIsError = false
          if (reply.id && root.macroBusy === "saving") root.savedMacroId = String(reply.id)
        } else {
          root.notice = reply && reply.error ? String(reply.error) : "The keyboard didn't take that."
          root.noticeIsError = true
        }
      }
    }
    stderr: SplitParser { onRead: function(line) {} }
    onExited: {
      root.macroBusy = ""
      if (!macrosProcess.running) macrosProcess.running = true
    }
  }

  function runMacro(kind, args, payload) {
    if (macroProcess.running) return
    root.notice = ""
    root.macroBusy = kind
    macroProcess.payload = payload || ""
    macroProcess.command = root.ctl(60, args)
    macroProcess.running = true
  }

  function saveMacro(macro) {
    root.savedMacroId = ""
    runMacro("saving", ["macro", "save"], JSON.stringify(macro))
  }

  // Takes another macro off its key (the key goes back to normal) without
  // switching the editor to it.
  function freeKey(macro) {
    runMacro("freeing", ["macro", "save"], JSON.stringify(macro))
  }

  function deleteMacro(id) {
    runMacro("deleting", ["macro", "delete", String(id)])
  }
}
