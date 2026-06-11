# PS Vita Example Builds

`scripts/build_vita_examples.sh` builds and packages the repository examples for
PS Vita with VitaSDK. The script copies `nim_vita.cfg` to the repository root as
`nim.cfg` for the duration of the build, restores the previous `nim.cfg` on
exit, and writes artifacts under `build/vita/` by default.

## Prerequisites

- Nim on `PATH`.
- VitaSDK installed at `/usr/local/vitasdk`, or `VITASDK` set to the installed
  SDK root.
- VitaSDK tools on disk:
  - `arm-vita-eabi-gcc`
  - `arm-vita-eabi-g++`
  - `arm-vita-eabi-ar`
  - `vita-elf-create`
  - `vita-make-fself`
  - `vita-mksfoex`
- `zip` on `PATH`.

The script prepends `$VITASDK/bin` to `PATH`, so a standard VitaSDK install does
not need additional shell setup beyond `VITASDK`.

## Build

From the repository root:

```sh
scripts/build_vita_examples.sh
```

To write artifacts somewhere else:

```sh
scripts/build_vita_examples.sh --out-dir build/vita-local
```

For a non-default SDK location:

```sh
VITASDK=/path/to/vitasdk scripts/build_vita_examples.sh
```

The script builds each example with:

```sh
nim c -d:vita --path:examples --out:<output> <example>
```

It currently packages:

- `examples/phase1_public_api.nim`
- `examples/bus_volume_demo.nim`
- `examples/music_fades.nim`
- `examples/sfx_keypress.nim`

With the default output directory, each example produces:

- A Vita ELF at `build/vita/<name>`.
- A VELF at `build/vita/<name>.velf`.
- A self at `build/vita/<name>-eboot.bin`.
- A package at `build/vita/<name>.vpk`.

When `--out-dir` is provided, replace `build/vita` with that directory.

## Packaging Commands

For each built example, the script runs the VitaSDK packaging tools in this
order:

```sh
vita-elf-create <out-dir>/<name> <out-dir>/<name>.velf
vita-make-fself <out-dir>/<name>.velf <out-dir>/<name>-eboot.bin
vita-mksfoex -s "TITLE_ID=<TITLEID>" <name> <out-dir>/<name>-param.sfo
```

It then stages:

```text
eboot.bin
sce_sys/param.sfo
tests/fixtures/generated/
```

and creates the `.vpk` with `zip`. The fixture directory is included because
the examples load their shared audio files from `tests/fixtures/generated/` on
console builds.

## Link Stubs

Nim's generated link line may reference `-lrt`, but VitaSDK does not provide a
real `librt.a`. During the build, the script creates an empty root
`librt.a` stub with `arm-vita-eabi-ar`, then removes it during cleanup. If a
root `librt.a` already exists, the script fails instead of overwriting it.

## Backend

`-d:vita` maps through `config.nims` to `playPlatformVita`.
`src/play/private/soloud_sources.nim` then compiles SoLoud with
`WITH_VITA_HOMEBREW` and includes
`vendor/soloud/src/backend/vita_homebrew/soloud_vita_homebrew.cpp`.

The example defaults use Play's platform default backend on Vita, so the
packaged examples initialize the real SoLoud Vita homebrew audio backend rather
than the host null backend.

## Verification

The build script should leave the repository root `nim.cfg` exactly as it found
it and should not leave `librt.a` behind:

```sh
before=$(shasum -a 256 nim.cfg | awk '{print $1}')
scripts/build_vita_examples.sh --out-dir build/vita
after=$(shasum -a 256 nim.cfg | awk '{print $1}')
test "$before" = "$after"
test ! -e librt.a
```

Hardware audio behavior still requires a Vita or emulator setup that can run the
generated `.vpk` files; see `docs/vita-hardware-verification.md` for the human
verification checklist.
