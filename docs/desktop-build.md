# Desktop Example Builds

Desktop example builds are agent-verifiable. They compile and run on the host
without requiring console SDKs or hardware.

## Prerequisites

- Nim on `PATH`.
- Bash-compatible shell.

## Smoke Build

From the repository root:

```sh
bash scripts/build_desktop_examples.sh --smoke
```

That command builds and runs:

- `examples/phase1_public_api`
- `examples/bus_volume_demo --quiet`
- `examples/music_fades --quiet`
- `examples/sfx_keypress --keys=sq --quiet`

The smoke path uses each example's headless default backend and is suitable for
CI.

## Artifact Paths

Desktop examples are emitted next to their source files:

- `examples/phase1_public_api`
- `examples/bus_volume_demo`
- `examples/music_fades`
- `examples/sfx_keypress`

On Windows, the same paths use the platform executable suffix.

## Audio-Path Build

To request each example's non-null default backend path:

```sh
bash scripts/build_desktop_examples.sh --audio
```

Current desktop builds compile SoLoud's `NOSOUND` and `NULL` backends. Until a
host hardware backend is added to the source closure, this verifies the example
runtime path but does not prove speaker output.

See `docs/desktop-verification.md` for the host-specific verification notes.
