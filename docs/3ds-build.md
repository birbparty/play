# Nintendo 3DS Example Builds

`scripts/build_3ds_examples.sh` builds and packages the repository examples for
Nintendo 3DS with devkitARM and libctru. The script copies `nim_3ds.cfg` to the
repository root as `nim.cfg` for the duration of the build, restores the
previous `nim.cfg` on exit, and writes artifacts under `build/3ds/` by default.

No clckr integration is required for this build path.

## Prerequisites

- Nim on `PATH`.
- devkitPro installed and `DEVKITPRO` set, usually:

```sh
export DEVKITPRO=/opt/devkitpro
```

- `DEVKITARM` set, or left unset so the script defaults it to
  `$DEVKITPRO/devkitARM`.
- devkitARM and devkitPro tools on disk:
  - `arm-none-eabi-gcc`
  - `arm-none-eabi-g++`
  - `arm-none-eabi-ar`
  - `3dsxtool`

The script prepends `$DEVKITPRO/tools/bin` and `$DEVKITARM/bin` to `PATH`.

## Build

From the repository root:

```sh
DEVKITPRO=/opt/devkitpro scripts/build_3ds_examples.sh
```

To write artifacts somewhere else:

```sh
DEVKITPRO=/opt/devkitpro scripts/build_3ds_examples.sh --out-dir build/3ds-local
```

The script builds each example with:

```sh
nim c -d:ds3 --path:examples --out:<out-dir>/<name>.elf <example>
```

It currently packages:

- `examples/phase1_public_api.nim`
- `examples/bus_volume_demo.nim`
- `examples/music_fades.nim`
- `examples/sfx_keypress.nim`
- `examples/ds3_audio_probe.nim` (3DS-only hardware diagnostic; not part of
  the shared examples list used by the desktop and Vita builds)

With the default output directory, each example produces:

- A 3DS ELF at `build/3ds/<name>.elf`.
- A 3DSX at `build/3ds/<name>.3dsx`.

When `--out-dir` is provided, replace `build/3ds` with that directory.

## Packaging Command

For each built example, the script runs:

```sh
3dsxtool <out-dir>/<name>.elf <out-dir>/<name>.3dsx
```

The examples load shared audio files from `sdmc:/tests/fixtures/generated/` on
3DS builds. The script stages those fixtures under:

```text
<out-dir>/sdroot/tests/fixtures/generated/
```

Copy the contents of `<out-dir>/sdroot/` to the SD card root before running the
examples on hardware; that creates the `sdmc:/tests/fixtures/generated/` path.

## Backend

`-d:ds3` maps through `config.nims` to `playPlatform3ds`.
`src/play/private/soloud_sources.nim` then compiles SoLoud with
`WITH_CTRU_NDSP` and includes
`vendor/soloud/src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp`.

The example defaults use Play's platform default backend on 3DS, so the
packaged examples initialize the real SoLoud `ctru_ndsp` backend rather than the
host null backend.

## Hardware Notes

Real hardware needs `sdmc:/3ds/dspfirm.cdc` on the SD card for NDSP audio
output. This repository does not generate or distribute that firmware file.

For a hardware test, copy:

```text
build/3ds/<name>.3dsx
build/3ds/sdroot/tests/fixtures/generated/
3ds/dspfirm.cdc
```

to the SD card layout expected by the homebrew launcher.

## Verification

The build script should leave the repository root `nim.cfg` exactly as it found
it:

```sh
before=$(shasum -a 256 nim.cfg | awk '{print $1}')
DEVKITPRO=/opt/devkitpro scripts/build_3ds_examples.sh --out-dir build/3ds
after=$(shasum -a 256 nim.cfg | awk '{print $1}')
test "$before" = "$after"
```

Hardware audio behavior still requires a 3DS setup with `dspfirm.cdc`; see
`docs/3ds-hardware-verification.md` for the human verification checklist.
