# OmaRT100

Epomaker RT100 keyboard controls for [Omarchy](https://omarchy.org): pictures
and GIFs on the keyboard's little screen, key lights that follow your theme,
your own per-key colors, the built-in effects, profiles and macros. No
Windows, no browser, no Epomaker app. Every color and font follows your
Omarchy theme.

![OmaRT100 window](preview.png)

## What it does

OmaRT100 opens as a large window in the middle of the screen. Behind it, a
faint OMART100 in the font of the Omarchy logo repeats in diagonal rows, in
the theme's accent color.

| Tab | What you can do |
| --- | --- |
| Screen | Drop a picture, a GIF or a GIPHY link onto the window, or pick a file. Move and zoom it with the mouse or the arrow buttons, then send it. The left side shows what the keyboard screen has now. |
| Lights | **Follow theme**: keys take your theme's window border colors; a gradient border spreads across the keyboard from left to right. **My colors**: paint keys one by one or fill a group (WASD, arrows, F keys, numbers, letters, number pad), with swatches and a full color picker, then send it in one go. **Effects**: the keyboard's 19 built-in effects with speed, brightness, direction and color. |
| Profiles | Save the lights and the screen picture together, then switch between setups with one click. |
| Macros | Record keys or type text, choose how it plays (each press, while held, or on/off), and put it on a key or on Fn + a key. |

![Macros tab](docs/macros.png)

![Profiles tab](docs/profiles.png)

Every color follows your Omarchy theme, the keys on the keyboard included.
Here it is in Catppuccin, Ethereal, Hackerman and Tokyo Night:

![OmaRT100 in four themes](docs/themes.png)

![The Macros tab in four themes](docs/themes-macros.png)

While the shell runs, a small background helper keeps the keyboard screen's
CPU load and temperature live and its clock in sync. When you change themes,
the keys follow.

Macros are saved on the keyboard itself. The keyboard plays them on its own,
so they work on any computer, with or without OmaRT100 running. Deleting a
macro puts its key back the way it was.

## Supported keyboards

The Epomaker RT100 plugged in by **USB cable** (USB `3151:4015`, also
`3151:4010`). Check with:

```bash
lsusb | grep 3151:401
```

Set the keyboard's mode switch to **Off** (wired). Over the 2.4 GHz dongle or
Bluetooth the keyboard ignores these settings.

US ANSI layout. Tested on firmware 1.08.

## Install

You need Omarchy 4, the keyboard plugged in by cable, and these packages
(Omarchy already has most of them): `python`, `python-pillow`, `zenity`,
`util-linux`.

**1. Add the plugin.**

```bash
omarchy plugin add https://github.com/Dankestrick/OmaRT100.git --enable
```

That clones into `~/.config/omarchy/plugins/io.github.dankestrick.omart100/`.

**2. Let your session talk to the keyboard (one time, needs root).** The
keyboard's settings channel is a `/dev/hidraw` node that only root can open
until a udev rule allows it. The rule ships with the plugin in
[`udev/70-omart100.rules`](udev/70-omart100.rules), so you can read it first.
Copy it into place and reload udev:

```bash
sudo install -m 0644 ~/.config/omarchy/plugins/io.github.dankestrick.omart100/udev/70-omart100.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Then unplug the keyboard's cable and plug it back in. This is the only step
that needs root. See [Permissions and safety](#permissions-and-safety) for
exactly what it allows.

Do not symlink a git checkout into the plugins folder. Omarchy rejects a
plugin tree that is a symlink.

## Open it

```bash
omarchy-shell shell toggle io.github.dankestrick.omart100 '{}'
```

Run it again to close the window, or press `Esc` or SUPER + W. To open
straight to a tab, pass its name: `'{"tab":"macros"}'` (`screen`, `lights`,
`profiles`, `macros`).

To bind it to a key, add a line like this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + K", "OmaRT100", "omarchy-shell shell toggle io.github.dankestrick.omart100 '{}'")
```

## Use

### Screen

Drag a picture or GIF from your file manager onto the window, paste a link
(GIPHY page links work) and press **Open link**, or press **Choose file…**.
Then place it: drag to move, scroll to zoom, or use the arrow and zoom
buttons, and press **Send to keyboard**. A still picture takes about 8
seconds, a GIF up to 30. Still pictures fill the screen (162 × 173); GIFs play
at up to 128 × 160 and 56 frames.

### Lights

In **My colors**, painting only changes the map in the window. Press **Send
to keyboard** when you're ready, or **Undo changes** to go back to what the
keyboard has. The keyboard needs a moment between color changes, so OmaRT100
spaces them out. Numpad Enter has no light.

### Macros

1. Press **New macro** and give it a name.
2. Press **Record**, press the keys, then press **Stop**. Or type text into
   **Text to type** and press **Add text**. Click a step to remove it.
3. Pick how it plays: **Each press** (and how many times), **While held**, or
   **On / off**. Pick **As recorded** to keep your timing, or **Fast**.
4. Pick **Key alone** or **Fn + key**, then click a key on the map.
5. Press **Save to keyboard**.

**Key alone** replaces what the key types. **Fn + key** keeps the key's normal
job and plays the macro when you hold Fn. Dimmed keys already do something
with Fn (media keys, wireless modes and so on) and can't be picked, and the
Fn key itself is never changed. Recording happens inside the window, so
shortcuts Hyprland uses (like SUPER + something) can't be recorded.

## Permissions and safety

OmaRT100 runs as a normal Omarchy plugin, with your user's permissions.

- **One root step, at install.** Step 2 copies one udev rule into
  `/etc/udev/rules.d/`. After that, nothing needs root. At runtime, OmaRT100
  does not use sudo or pkexec, and it installs no services.
- **What the rule allows.** It matches only the RT100's hidraw nodes (USB
  `3151:4010` and `3151:4015`) and tags them `uaccess`, which gives the user at
  the active local session read and write access, the same way Linux handles
  game controllers. No other device is affected.
- **What it talks to.** Only the keyboard's control interface (USB interface
  2). Interface 0 carries your typing; OmaRT100 never opens it and never sees
  what you type. Macro recording reads keys only while the window has focus
  and you have pressed **Record**.
- **Network.** Only when you give it a link: it downloads that picture or GIF
  (for a GIPHY page, the GIF behind it).
- **What it runs.** Its own helper (`helpers/omart100ctl`, plain Python) for as
  long as the shell runs; it ends with the shell. Commands go to the helper
  as argument lists, never through a shell. `zenity` opens the file picker.
- **What it writes.** On disk, only `~/.local/state/omart100/`: settings,
  profiles, macros, and a copy of what's on the screen. Socket:
  `$XDG_RUNTIME_DIR/omart100.sock`, private to you (0600).
- **What it changes on the keyboard.** Lights, the screen picture, macro
  slots 1 to 32, and the keys you put macros on. Before changing a key it
  saves what the key did, and puts that back when you delete the macro.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| "Keyboard not found" | Plug in the cable and set the switch to Off. Check that `lsusb` lists `3151:4015`. |
| "Can't open /dev/hidraw…" | Do install step 2, then unplug and replug the cable. |
| The whole keyboard went plain white | It got color changes too fast. Pick the lights again in the Lights tab. |
| The picture only half shows | Send it again and leave the keyboard alone until it finishes. |
| A macro key types its old letter | The macro is on another of the keyboard's own profiles. Switch back, or save the macro again. |

The helper also works from a terminal, which helps when reporting a problem:

```bash
python3 ~/.config/omarchy/plugins/io.github.dankestrick.omart100/helpers/omart100ctl status
```

## Remove

Delete your macros first (Macros tab, **Delete macro**), so their keys go back
to normal. Then:

```bash
omarchy plugin remove io.github.dankestrick.omart100 --yes
```

Omarchy keeps a backup copy named
`~/.config/omarchy/plugins/.io.github.dankestrick.omart100.bak.<date>`, which
you can delete. To remove your saved settings, profiles and macros list too:

```bash
rm -rf ~/.local/state/omart100
```

Removing the udev rule needs root, like installing it:

```bash
sudo rm -f /etc/udev/rules.d/70-omart100.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Credits

- Screen, light and effect commands come from
  [strodgers/epomaker-controller](https://github.com/strodgers/epomaker-controller) (MIT).
- The key positions started from
  [dwaycik/epomaker-rt100](https://github.com/dwaycik/epomaker-rt100) (MIT);
  the bottom row and key slots were corrected on real hardware.
- Macro and key commands come from
  [ramarivera/epomaker-driver-linux](https://github.com/ramarivera/epomaker-driver-linux) (MIT).

OmaRT100 is not made by or affiliated with Epomaker.

## License

[MIT](LICENSE)
