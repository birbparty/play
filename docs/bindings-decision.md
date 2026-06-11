# SoLoud Binding Decision

`play` will use handwritten Nim bindings for the phase-1 `soloud_c.h` surface.
Futhark remains useful as a spike/reference tool, but the raw generated output is
not the committed binding layer.

## Decision

Implement `src/play/bindings/**` by hand over the generated SoLoud C API.

The handwritten scope should cover only the phase-1 public wrapper needs:

- Engine lifecycle and diagnostics:
  `Soloud_create`, `Soloud_destroy`, `Soloud_init`, `Soloud_initEx`,
  `Soloud_deinit`, `Soloud_getErrorString`, backend metadata, and
  `Soloud_setGlobalVolume`
- Playback and handles:
  `Soloud_play`, `Soloud_playEx`, `Soloud_playBackground`,
  `Soloud_playBackgroundEx`, `Soloud_stop`, `Soloud_stopAll`,
  `Soloud_setPause`, `Soloud_setLooping`, `Soloud_setVolume`,
  `Soloud_isValidVoiceHandle`, and `Soloud_setMaxActiveVoiceCount`
- Fades and scheduling:
  `Soloud_fadeVolume`, `Soloud_fadeGlobalVolume`, `Soloud_schedulePause`,
  and `Soloud_scheduleStop`
- Manual mixing fallback:
  `Soloud_mixSigned16`
- Fixed bus support:
  `Bus_create`, `Bus_destroy`, `Bus_play`, `Bus_playEx`, `Bus_setVolume`,
  and `Bus_stop`
- Resident and streaming assets:
  `Wav_*` and `WavStream_*` functions required by phase-1 WAV and OGG loading

Keep raw bindings internal to implementation modules. The public `play` API
should not expose raw SoLoud pointers, C enum names, or C voice ids.

## Futhark Spike Result

Futhark was installed in an isolated temporary Nimble directory:

```sh
nimble --nimbleDir:/tmp/play-futhark-spike/nimble install -y futhark
```

The installed generator was Futhark `0.16.0`. Its compile-time dependencies
included `libclang-nim`, `macroutils`, `nimbleutils`, `termstyle`, and the
`opir` helper binary.

A scratch wrapper over `vendor/soloud/include/soloud_c.h` compiled and linked
on host when `opir` was supplied explicitly:

```nim
import futhark

importc:
  path "/Users/punk1290/git/play/vendor/soloud/include"
  "soloud_c.h"
```

The host smoke program imported that wrapper plus `play/soloud_compile`, called
`Soloud_create`, asserted the returned pointer was non-nil, and called
`Soloud_destroy`. It compiled with `nim c` and linked through the existing
`soloud_c.cpp` compile model.

Without the `opirBin` strdefine or `opir` on `PATH`, generation failed with:

```text
Error: Opir exited with non-zero exit code 127.
/bin/sh: opir: command not found
```

This confirms that Futhark must remain a development-time generator if used at
all. Consumers must not need Futhark, `opir`, or libclang.

## Generated Output Check

Futhark can emit committed Nim output with `outputPath`; the generated
`soloud_c.h` wrapper was about 191 KB in the spike. That committed-output style
type-checked without Futhark for:

- host `nim check`
- `-d:ds3` with the 3DS cfg copied to `nim.cfg`
- `-d:vita` with the Vita cfg copied to `nim.cfg`

The generated-output host program also compiled and linked with
`play/soloud_compile`.

However, the raw generated API is not clean enough to commit as the raw binding
surface:

- Duplicate C enum values are emitted as aliases to unrelated earlier enum
  names. For example, `SOLOUD_CLIP_ROUNDOFF = 1` becomes an alias to the backend
  enum value `SOLOUD_SDL1`. The numeric value is preserved, but the API is
  misleading and hard to review.
- The generated module exposes the full generated SoLoud C API, including
  optional audio sources and filters outside phase 1.
- The generated module emits guard noise around names that collide with Nim
  identifiers, such as `File`.
- Post-processing enough of the output to make it reviewable would become a
  second generator maintenance surface.

## Cross-Compile Notes

The generated-only Futhark output type-checked for both console defines. The
existing SoLoud compile module also passed console `--compileOnly` checks in the
spike.

Full 3DS backend execution remains out of scope for this decision. The SoLoud
fork still needs the separate libctru thread/mutex port and a real NDSP backend
before 3DS audio can link and run as a real backend. That limitation applies
regardless of Futhark versus handwritten Nim declarations.

## Follow-Up Contract

The next raw-binding bead should create the handwritten binding files and tests.
It should use Futhark output only as a comparison aid for C signatures and enum
numeric values. Do not add Futhark to `play.nimble`, and do not require
downstream projects to install libclang.
