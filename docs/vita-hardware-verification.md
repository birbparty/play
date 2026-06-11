# PS Vita Hardware Verification

This is the human hardware gate for the Vita example artifacts.
Cross-compilation and VPK packaging are agent-verifiable through
`docs/vita-build.md`; real audio output requires a Vita or emulator setup that
can launch the generated VPKs.

## Build Command

From the repository root:

```sh
scripts/build_vita_examples.sh --out-dir build/vita
```

Set `VITASDK=/path/to/vitasdk` first if VitaSDK is not installed at
`/usr/local/vitasdk`.

## Artifact Paths

Expected package outputs:

- `build/vita/vita_audio_probe.vpk`
- `build/vita/phase1_public_api.vpk`
- `build/vita/bus_volume_demo.vpk`
- `build/vita/music_fades.vpk`
- `build/vita/sfx_keypress.vpk`

The script also emits each intermediate ELF, VELF, EBOOT, and param SFO next to
the VPK. Each VPK includes:

```text
eboot.bin
sce_sys/param.sfo
tests/fixtures/generated/
```

## Hardware Prerequisites

- A PS Vita or emulator setup capable of installing/running homebrew VPKs.
- Vita homebrew permissions sufficient to access packaged files.

## Run The Diagnostic Probe First

Install and launch `vita_audio_probe.vpk` before the other examples. The other
examples are short headless smoke programs: on hardware they show a black
screen briefly and exit even when they succeed, so they cannot distinguish
success from early failure on their own.

The probe paints the screen a distinct solid color per phase, plays five SFX
beeps with white screen flashes, plays about eight seconds of streamed music,
and writes a flushed log to `ux0:/data/play-vita-probe.log`:

- dark blue: probe started, engine init in progress
- dark gray (about 2 s flash): the log file could not be opened; the probe
  continues without it
- dark green (brief): engine init succeeded
- cyan: assets loaded, beep pattern starting
- white flashes: each SFX beep
- yellow: streamed music playing
- bright green (about 10 s final hold): probe finished successfully, then exits
- red (about 20 s hold): engine init failed
- magenta (about 20 s hold): asset load failed
- orange (about 20 s hold): playback returned an invalid handle
- pink (about 20 s hold): unexpected error; details in the log

Record the colors seen, whether beeps and music were audible, and the contents
of `ux0:/data/play-vita-probe.log`. A black screen with no color at all means
the app died before its first frame; check whether the log file was created to
narrow how far it got.

## Expected Behavior

- `vita_audio_probe.vpk`: runs the color/beep/log sequence above and exits on
  its own after the final green hold.
- `phase1_public_api.vpk`: initializes Play, exercises public volume, sound,
  music, handle, and fade APIs, then exits without an error screen.
- `bus_volume_demo.vpk`: initializes the SoLoud Vita homebrew backend, plays the
  shared music fixture on the music bus, plays the click SFX on the SFX and UI
  buses, applies volume changes, then exits.
- `music_fades.vpk`: initializes the SoLoud Vita homebrew backend, plays
  streamed OGG music, fades it in and out, then exits.
- `sfx_keypress.vpk`: initializes the SoLoud Vita homebrew backend, uses
  scripted key input by default, plays the click SFX, then exits.

## Hardware Result

Status: pending human verification.

Record the tested hardware or emulator, command used to build artifacts, which
VPKs were installed/launched, observed audio/output behavior, and any crash or
error text.

## Follow-Up Failures

If hardware verification fails, open a new Bead for each distinct failure and
link it from `play-2fv`. Include the exact VPK path, hardware/emulator setup,
observed behavior, and a minimal reproduction.
