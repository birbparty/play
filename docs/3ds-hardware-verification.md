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
tests/fixtures/generated/tone_music_long.ogg
3ds/dspfirm.cdc
```

## Expected Behavior

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
