# Nintendo 3DS Hardware Verification

This is the human hardware gate for the 3DS example artifacts. Cross-compilation
is agent-verifiable through `docs/3ds-build.md`; real NDSP audio output requires
a physical 3DS setup.

## Build Command

From the repository root:

```sh
DEVKITPRO=/opt/devkitpro scripts/build_3ds_examples.sh --out-dir build/3ds
```

Use a different `DEVKITPRO` value if devkitPro is installed elsewhere.

## Artifact Paths

Expected build outputs:

- `build/3ds/ds3_audio_probe.3dsx`
- `build/3ds/phase1_public_api.3dsx`
- `build/3ds/bus_volume_demo.3dsx`
- `build/3ds/music_fades.3dsx`
- `build/3ds/sfx_keypress.3dsx`
- `build/3ds/sdroot/tests/fixtures/generated/`

The matching ELF files are also emitted next to the `.3dsx` files.

## Hardware Prerequisites

- A 3DS capable of running homebrew `.3dsx` files.
- `sdmc:/3ds/dspfirm.cdc` on the SD card for NDSP audio output.
- The staged fixture directory copied to the SD card root so the examples can
  read `sdmc:/tests/fixtures/generated/`.

This repository does not generate or distribute `dspfirm.cdc`.

## SD Card Layout

Copy each `.3dsx` file to the location expected by the homebrew launcher. Copy
the contents of `build/3ds/sdroot/` to the SD card root.

The SD card should contain:

```text
tests/fixtures/generated/tone_sfx.wav
tests/fixtures/generated/tone_music.ogg
tests/fixtures/generated/tone_music.wav
tests/fixtures/generated/tone_music_long.ogg
3ds/dspfirm.cdc
```

## Run The Diagnostic Probe First

Install and launch `ds3_audio_probe.3dsx` before the other examples. The other
examples are short headless smoke programs: on hardware they show a black
screen briefly and exit even when they succeed (confirmed on PS Vita via
`vita_audio_probe.vpk`), so they cannot distinguish success from early failure
on their own.

The probe prints live status text to the top screen via the libctru console,
plays five SFX beeps, then plays a four-phase music matrix of about five
seconds per phase with a one-second silence gap between phases, writes a
flushed log to `sdmc:/play-3ds-probe.log`, and holds about 10 s on success or
about 20 s on any failure before exiting (START skips the current hold).

The music matrix phases vary content, decode location, file I/O, and bus, so
reporting which phases were audible attributes a silent-music failure to the
right layer:

- `MUSIC CTRL: LOOPED SFX TONE, MUSIC BUS` — the same 880 Hz tone as the
  beeps, configured exactly like the music phases (looping, volume 0.8,
  music bus); isolates content from looping/volume/bus
- `MUSIC A: STREAMED OGG` — vorbis decode and file reads in the mixer thread,
  music bus
- `MUSIC B: STREAMED WAV` — file reads in the mixer thread, no vorbis,
  music bus
- `MUSIC C: PRELOADED OGG, SFX BUS` — vorbis decoded at load on the main
  thread
- `MUSIC D: PRELOADED OGG, MUSIC BUS` — same source as C, isolates the bus

What to listen for: the beeps and the control phase are a high tone (880 Hz);
phases A through D are a continuous lower tone (440 Hz, one octave down). The
music fixtures were originally 220 Hz, which plays correctly but is below the
3DS speakers' rolloff and inaudible — when re-running after a fixture change,
re-copy `build/3ds/sdroot/` to the SD card root, or stale fixture files at
`sdmc:/tests/fixtures/generated/` (or `sdmc:/examples/assets/`, which the
probe prefers when present) will silently reintroduce old content; the
probe's `asset selected:` log line records which file was actually used.

The final banner is one of:

- `SUCCESS` — full sequence completed
- `PARTIAL - SOME MUSIC PHASES FAILED` — a matrix phase failed to load or
  play; per-phase details in the log
- `INIT FAILED` — engine/NDSP init failed (usually a missing
  `sdmc:/3ds/dspfirm.cdc`)
- `SFX LOAD FAILED` / `MUSIC LOAD FAILED` — fixture files not found; the log
  lists every candidate path with an existence check
- `SFX PLAY FAILED` — beep playback returned an invalid handle
- `UNEXPECTED ERROR` — an exception; details in the log

Record the last banner, **which of phases A/B/C/D were audible**, and the
contents of `sdmc:/play-3ds-probe.log`. A completely blank screen means the
app died before console init; check whether the log file was created to
narrow how far it got.

## Expected Behavior

- `ds3_audio_probe.3dsx`: runs the console/beep/log sequence above and exits
  on its own after the final hold.
- `phase1_public_api.3dsx`: initializes Play, exercises public volume, sound,
  music, handle, and fade APIs, then exits without an error screen.
- `bus_volume_demo.3dsx`: initializes the 3DS `ctru_ndsp` backend, plays the
  shared music fixture on the music bus, plays the click SFX on the SFX and UI
  buses, applies volume changes, then exits.
- `music_fades.3dsx`: initializes the 3DS `ctru_ndsp` backend, plays streamed
  OGG music, fades it in and out, then exits.
- `sfx_keypress.3dsx`: initializes the 3DS `ctru_ndsp` backend, uses scripted
  key input by default, plays the click SFX, then exits.

## Hardware Result

Status: pending human verification.

Record the tested hardware, SD card layout, command used to build artifacts,
which `.3dsx` files were launched, observed audio/output behavior, and any
crash or error text.

## Follow-Up Failures

If hardware verification fails, open a new Bead for each distinct failure and
link it from `play-xu8`. Include the exact artifact path, hardware model,
`dspfirm.cdc` status, observed behavior, and a minimal reproduction.
