# Marbly

[![CI](https://github.com/nidheesh-m-vakharia/marbly/actions/workflows/ci.yml/badge.svg)](https://github.com/nidheesh-m-vakharia/marbly/actions/workflows/ci.yml)

Your Mac's Dock, as a row of mechanical keycaps.

Marbly reads the apps in your Dock and draws them as sculpted keys on a small keyboard
at the bottom of the screen. Each keycap takes its colour from the app's icon, with a
lit top face, shaded walls, a glossy sheen and a reflection below the board. Pressing a
key plays a switch sound and opens the app.

## Run

```sh
swift run                 # debug build, runs in place
./scripts/bundle.sh       # release build → build/Marbly.app
```

Open the menu bar's keyboard icon and choose **Open Marbly…** (⌘,) for the control window:

- **Appearance**: six themes, the case colour, and light or dark for the window
- **Lighting**: light direction, highlight strength, gloss and shadow depth
- **Keyboard**: keycap profile (Cherry, SA, DSA, Low profile), what fills the space between
  keys (plate, body, a colour, or a per-key backlight), key size, legend, reflection
- **Sound**: eight switch profiles, volume, release sounds
- **Dock**: replacing the Dock, auto-hide, covering the Dock in Mission Control
- **Permissions**: Accessibility status and open at login

## Sounds

The switch sounds come from [mechsound](https://github.com/airodynamic07/mechanical-keyboard-sound),
rendered once to WAV files. Generate them before building:

```sh
python3 -m venv .venv
.venv/bin/pip install numpy
.venv/bin/pip install --no-deps git+https://github.com/airodynamic07/mechanical-keyboard-sound
.venv/bin/python scripts/generate_sounds.py
```

Until then, each profile falls back to Marbly's built-in synthesiser.

## Replacing the Dock

Marbly sits where the Dock is and stops the real one from appearing. It does this by
setting the Dock to auto-hide with a 1000-second reveal delay. Your original settings are
saved first and put back when Marbly quits, including on Ctrl-C or `kill`.

If your Dock was set to auto-hide, Marbly does the same: it stays off-screen and slides up
when the pointer reaches the bottom edge, after your Dock's own delay. With Reduce Motion
on, it fades instead of sliding. Both options are under **Dock** in the menu.

Mission Control always draws the real Dock. With Accessibility access, Marbly listens
for the Dock's Mission Control notifications, rises above the overlay and covers it.
The real Dock's icons are shrunk to the minimum while Marbly runs so the board hides it
fully; the size is restored on quit.

If Marbly is force-quit and the Dock stays hidden, relaunch and quit Marbly, or run:

```sh
defaults delete com.apple.dock autohide-delay; defaults delete com.apple.dock tilesize; killall Dock
```

Apps can't reserve screen space the way the Dock does, so with auto-hide off, maximised
windows can extend underneath the board.

Requires macOS 14 or later.

## How it works

macOS doesn't let apps restyle the real Dock, so Marbly draws a replacement:

- **Apps** come from `persistent-apps` in `com.apple.dock`, plus any running apps that
  aren't pinned. Finder is always first.
- **Colour**: each icon is sampled at 24×24 and the strongest saturated hue family wins.
  Mostly grey icons give grey keys.
- **Sound** is synthesised at runtime: a noise transient, a pitched body thump and a
  plastic resonance, plus click-jacket snaps on clicky switches. There are no audio files.
  Each key is panned by its position on the board.

## Staying light

At idle Marbly sits at 0% CPU and about 30 MB of physical memory.

- Auto-hide doesn't watch the mouse. A 2 px invisible strip along the bottom edge
  only wakes Marbly when the pointer enters it. While hidden, the board's window is
  removed from the screen, so nothing is drawn.
- Nothing polls. Changes arrive through a kernel file watch on the Dock plist and
  `NSWorkspace` launch/quit notifications, and bursts of them are merged into one reload.
- Each icon is rasterised once to a 96 px bitmap and cached. The full `.icns` image isn't
  kept, and entries for apps that leave the Dock are dropped from the cache.
- Only the selected switch's sound buffers are kept in memory (~120 KB).
- The audio engine starts on the first keypress and stops after 3 seconds of silence.
  A running `AVAudioEngine` keeps the audio thread busy even when nothing is playing.
- Keycap shading is all gradients, with no blur passes. The board is flattened into one
  layer with `drawingGroup()`, so it only redraws when its state changes.

## Develop

```sh
swift test
swift run Marbly --snapshot board.png             # render the board to a PNG and exit
swift run Marbly --snapshot-settings out/ --dark  # render every settings page
```

## Credits

- Font: [Open Runde](https://github.com/lauridskern/open-runde) by Laurids Kern, a rounded
  [Inter](https://rsms.me/inter/), licensed under the SIL Open Font License 1.1
  (`Sources/Marbly/Resources/Fonts/OFL.txt`). Regular and Medium ship with the app and are
  registered for Marbly's process only. Tracking follows Inter's
  [Dynamic Metrics](https://rsms.me/inter/dynmetrics/) and line height is 1.4 × size.
- Icons: [Solar](https://www.figma.com/community/file/1166831539721848736) by 480 Design,
  Bold style, licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  Embedded by `scripts/fetch_solar_icons.py` into `Sources/Marbly/Settings/SolarIcon.swift`.
- Switch sounds: [mechsound](https://github.com/airodynamic07/mechanical-keyboard-sound).

## Website

`site/` is the storefront for marbly.click: a SvelteKit app pre-rendered to static pages
(home, `/guide`, `/terms`). It shares the app's look: Radix slate and indigo, Open Runde
with the same four sizes and Inter metrics, and Solar icons. Motion uses the Web Animations
API: an intro that plays once per session, and press feedback.

```sh
cd site
pnpm install
pnpm dev        # http://localhost:5173
pnpm build      # static site in site/build
```

The showcase images in `site/static/showcase` are rendered from the app itself, with
`--snapshot`, `--snapshot-settings` and `--snapshot-windows`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the PR workflow and the design rules.
Security reports go through [SECURITY.md](SECURITY.md).
