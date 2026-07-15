# sprint-souls

A Dark Souls style fullscreen banner that appears the first time you log in,
unlock, or wake your Mac after a new sprint has started. The screen dims, a
letterbox band sweeps across the center, and gold serif text slowly expands —
then it all fades away. Click or press any key to dismiss early.

## How it works

A LaunchAgent runs a tiny background app at login. It listens for screen
unlock, wake, and fast-user-switch events. On each event it computes the most
recent sprint boundary (`anchor + n × intervalDays`); if the banner hasn't been
shown for that boundary yet, it plays once and records it in
`~/.config/sprint-souls/state.json`. So even if you're off on sprint day, you
still get it the next time you sit down.

## Menu bar

A flame icon in the menu bar shows the next sprint date and offers:

- **Set Schedule…** — date/time picker for the sprint start, repeat interval
  in days, and the banner text. Saves straight to the config file.
- **Play Animation Now** — preview without affecting the real schedule.
- **Quit Sprint Souls** — stops the agent until next login.

## Install

The quick way (downloads the latest prebuilt release, no toolchain needed):

```sh
curl -fsSL https://raw.githubusercontent.com/kidCubi/sprint-souls/main/get.sh | bash
```

Or grab the `.tar.gz` from the [releases page](https://github.com/kidCubi/sprint-souls/releases),
extract it, and run `./install.sh` inside.

From source (requires the Xcode Command Line Tools):

```sh
git clone https://github.com/kidCubi/sprint-souls.git
cd sprint-souls
./install.sh     # builds, installs to ~/.local/share/sprint-souls, loads the LaunchAgent
```

To uninstall, run `./uninstall.sh` (bundled in the release tarball too):

```sh
curl -fsSL https://raw.githubusercontent.com/kidCubi/sprint-souls/main/uninstall.sh | bash
```

## Preview

```sh
~/.local/share/sprint-souls/sprint-souls --preview
```

## Config — `~/.config/sprint-souls/config.json`

```json
{
  "anchor": "2026-07-16T08:00:00",
  "intervalDays": 14,
  "title": "SPRINT {n} STARTED",
  "subtitle": "Go forth",
  "soundPath": "/path/to/bonfire.aiff"
}
```

- `anchor` — date and time of any sprint start, local time. Every
  `intervalDays` from this point is a new sprint.
- `intervalDays` — 14 for a two-week cadence.
- `title` — the big gold text. `{n}` is replaced with the current sprint
  number (sprint 1 starts at the anchor).
- `subtitle` (optional) — smaller line under the title; `{n}` works here too.
- `soundPath` (optional) — sound file to play with the banner (`~` is
  expanded). If omitted, a file named `sound.mp3` / `sound.m4a` / `sound.aiff` /
  `sound.wav` dropped into `~/.config/sprint-souls/` is picked up automatically.

Config is re-read on every trigger, so edits apply without restarting the
agent. To force the banner to replay for the current sprint, delete
`~/.config/sprint-souls/state.json`.
