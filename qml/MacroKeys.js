.pragma library

// Recording and typing for the Macros tab. A key pressed in the window
// arrives with its XKB keycode (Linux evdev code + 8); the keyboard stores
// USB HID usages. Labels are what the step chips show.

var EVDEV = {
  1: [0x29, "Esc"], 2: [0x1e, "1"], 3: [0x1f, "2"], 4: [0x20, "3"], 5: [0x21, "4"],
  6: [0x22, "5"], 7: [0x23, "6"], 8: [0x24, "7"], 9: [0x25, "8"], 10: [0x26, "9"],
  11: [0x27, "0"], 12: [0x2d, "-"], 13: [0x2e, "="], 14: [0x2a, "Backspace"], 15: [0x2b, "Tab"],
  16: [0x14, "Q"], 17: [0x1a, "W"], 18: [0x08, "E"], 19: [0x15, "R"], 20: [0x17, "T"],
  21: [0x1c, "Y"], 22: [0x18, "U"], 23: [0x0c, "I"], 24: [0x12, "O"], 25: [0x13, "P"],
  26: [0x2f, "["], 27: [0x30, "]"], 28: [0x28, "Enter"], 29: [0xe0, "Ctrl"],
  30: [0x04, "A"], 31: [0x16, "S"], 32: [0x07, "D"], 33: [0x09, "F"], 34: [0x0a, "G"],
  35: [0x0b, "H"], 36: [0x0d, "J"], 37: [0x0e, "K"], 38: [0x0f, "L"], 39: [0x33, ";"],
  40: [0x34, "'"], 41: [0x35, "`"], 42: [0xe1, "Shift"], 43: [0x31, "\\"],
  44: [0x1d, "Z"], 45: [0x1b, "X"], 46: [0x06, "C"], 47: [0x19, "V"], 48: [0x05, "B"],
  49: [0x11, "N"], 50: [0x10, "M"], 51: [0x36, ","], 52: [0x37, "."], 53: [0x38, "/"],
  54: [0xe5, "R Shift"], 55: [0x55, "Num *"], 56: [0xe2, "Alt"], 57: [0x2c, "Space"],
  58: [0x39, "Caps"], 59: [0x3a, "F1"], 60: [0x3b, "F2"], 61: [0x3c, "F3"], 62: [0x3d, "F4"],
  63: [0x3e, "F5"], 64: [0x3f, "F6"], 65: [0x40, "F7"], 66: [0x41, "F8"], 67: [0x42, "F9"],
  68: [0x43, "F10"], 69: [0x53, "Num Lock"], 70: [0x47, "Scroll Lock"],
  71: [0x5f, "Num 7"], 72: [0x60, "Num 8"], 73: [0x61, "Num 9"], 74: [0x56, "Num -"],
  75: [0x5c, "Num 4"], 76: [0x5d, "Num 5"], 77: [0x5e, "Num 6"], 78: [0x57, "Num +"],
  79: [0x59, "Num 1"], 80: [0x5a, "Num 2"], 81: [0x5b, "Num 3"], 82: [0x62, "Num 0"],
  83: [0x63, "Num ."], 86: [0x64, "\\"], 87: [0x44, "F11"], 88: [0x45, "F12"],
  96: [0x58, "Num Enter"], 97: [0xe4, "R Ctrl"], 98: [0x54, "Num /"], 99: [0x46, "Print"],
  100: [0xe6, "AltGr"], 102: [0x4a, "Home"], 103: [0x52, "Up"], 104: [0x4b, "PgUp"],
  105: [0x50, "Left"], 106: [0x4f, "Right"], 107: [0x4d, "End"], 108: [0x51, "Down"],
  109: [0x4e, "PgDn"], 110: [0x49, "Insert"], 111: [0x4c, "Del"], 119: [0x48, "Pause"],
  125: [0xe3, "Super"], 126: [0xe7, "R Super"], 127: [0x65, "Menu"],
  183: [0x68, "F13"], 184: [0x69, "F14"], 185: [0x6a, "F15"], 186: [0x6b, "F16"],
  187: [0x6c, "F17"], 188: [0x6d, "F18"], 189: [0x6e, "F19"], 190: [0x6f, "F20"],
  191: [0x70, "F21"], 192: [0x71, "F22"], 193: [0x72, "F23"], 194: [0x73, "F24"]
}

function fromScanCode(xkbCode) {
  var entry = EVDEV[xkbCode - 8]
  return entry ? { usage: entry[0], label: entry[1] } : null
}

var LABEL_BY_USAGE = (function() {
  var out = {}
  for (var code in EVDEV) if (out[EVDEV[code][0]] === undefined) out[EVDEV[code][0]] = EVDEV[code][1]
  return out
})()

function label(usage) {
  return LABEL_BY_USAGE[usage] || ("Key " + usage)
}

function isModifier(usage) {
  return usage >= 0xe0 && usage <= 0xe7
}

// US layout: each character is a key, with or without Shift.
var PLAIN = "abcdefghijklmnopqrstuvwxyz1234567890"
var SYMBOLS = {
  " ": [0x2c, false], "\n": [0x28, false], "\t": [0x2b, false],
  "-": [0x2d, false], "_": [0x2d, true], "=": [0x2e, false], "+": [0x2e, true],
  "[": [0x2f, false], "{": [0x2f, true], "]": [0x30, false], "}": [0x30, true],
  "\\": [0x31, false], "|": [0x31, true], ";": [0x33, false], ":": [0x33, true],
  "'": [0x34, false], "\"": [0x34, true], "`": [0x35, false], "~": [0x35, true],
  ",": [0x36, false], "<": [0x36, true], ".": [0x37, false], ">": [0x37, true],
  "/": [0x38, false], "?": [0x38, true],
  "!": [0x1e, true], "@": [0x1f, true], "#": [0x20, true], "$": [0x21, true],
  "%": [0x22, true], "^": [0x23, true], "&": [0x24, true], "*": [0x25, true],
  "(": [0x26, true], ")": [0x27, true]
}

function charKey(ch) {
  var lower = ch.toLowerCase()
  var i = PLAIN.indexOf(lower)
  if (i >= 0) {
    var usage = i < 26 ? 0x04 + i : (lower === "0" ? 0x27 : 0x1e + i - 26)
    return [usage, ch !== lower]
  }
  return SYMBOLS[ch] || null
}

// Steps that type `text`; characters the keyboard can't type are skipped.
function typeSteps(text, delay) {
  var steps = []
  for (var i = 0; i < text.length; i++) {
    var key = charKey(text[i])
    if (!key) continue
    if (key[1]) steps.push({ usage: 0xe1, down: true, delay: delay, label: "Shift" })
    steps.push({ usage: key[0], down: true, delay: delay, label: label(key[0]) })
    steps.push({ usage: key[0], down: false, delay: delay, label: label(key[0]) })
    if (key[1]) steps.push({ usage: 0xe1, down: false, delay: delay, label: "Shift" })
  }
  return steps
}

// Chips for the step list: a press straight followed by its release is one
// tap ("C"); anything else shows as "Ctrl ▼" ... "Ctrl ▲".
function chips(steps) {
  var out = []
  for (var i = 0; i < steps.length; i++) {
    var s = steps[i]
    var name = s.label || label(s.usage)
    var next = steps[i + 1]
    if (s.down && next && !next.down && next.usage === s.usage && !isModifier(s.usage)) {
      out.push({ text: name, first: i, count: 2 })
      i += 1
    } else {
      out.push({ text: name + (s.down ? " ▼" : " ▲"), first: i, count: 1 })
    }
  }
  return out
}
