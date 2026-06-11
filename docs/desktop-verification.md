# Desktop Example Verification

The desktop examples are built and smoke-run by:

```sh
sh scripts/build_desktop_examples.sh --smoke
```

The smoke path uses each example's headless default backend so CI can verify
build and wrapper flow without an audio device:

- `examples/phase1_public_api`
- `examples/bus_volume_demo --quiet`
- `examples/music_fades --quiet`
- `examples/sfx_keypress --keys=sq --quiet`

To run the same examples while requesting each example's non-null default
backend path:

```sh
sh scripts/build_desktop_examples.sh --audio
```

That command builds all desktop examples and runs:

- `examples/phase1_public_api`
- `examples/bus_volume_demo --audio --quiet`
- `examples/music_fades --audio --quiet`
- `examples/sfx_keypress --audio --keys=sq --quiet`

Current host desktop builds compile SoLoud's `NOSOUND` and `NULL` backends.
That means `--audio` verifies the examples' non-null backend selection and
runtime path, but it does not prove speaker output on CoreAudio, ALSA, WASAPI,
or another hardware audio backend until those backends are added to the host
source closure.

`sfx_keypress` also supports interactive use. Run
`examples/sfx_keypress --audio`, press `s` or Space to play the WAV SFX, and
press `q` to quit.

## Observed Host Run

Verified on June 11, 2026:

- OS: macOS 26.5.1, Darwin 25.5.0, arm64
- Nim: 2.2.10
- Commands:
  - `scripts/build_desktop_examples.sh --smoke`
  - `scripts/build_desktop_examples.sh --audio`
- Result: all examples built and ran successfully. The `--audio` run completed
  through the currently compiled desktop host backend set, which is `NOSOUND`
  and `NULL` in this repository revision.

## macOS

From the repository root with `nim` on `PATH`, run:

```sh
sh scripts/build_desktop_examples.sh --smoke
sh scripts/build_desktop_examples.sh --audio
```

The `--smoke` path is suitable for CI and does not require an audio device. The
`--audio` path currently verifies the compiled non-null host backend path, which
is `NOSOUND` until a macOS hardware backend is added to the host build.

## Windows

From a shell with `nim` on `PATH`, run:

```sh
sh scripts/build_desktop_examples.sh --smoke
sh scripts/build_desktop_examples.sh --audio
```

If a POSIX shell is not available, use Git Bash, MSYS2, or WSL for the script.
Windows-native shells such as Git Bash or MSYS2 emit `.exe` binaries next to the
example sources. WSL emits Linux binaries unless configured for cross-compiling.

## Linux

From the repository root:

```sh
sh scripts/build_desktop_examples.sh --smoke
sh scripts/build_desktop_examples.sh --audio
```

The `--smoke` path does not require an audio device. The `--audio` path requires
the system audio backend and device access expected by SoLoud on that host after
a Linux hardware backend is added to the host source closure; until then it
exercises the compiled `NOSOUND` backend path.
