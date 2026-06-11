# 3DS NDSP SoLoud Backend Implementation

`vendor/soloud/` includes birbparty/soloud fork commit
`bbf82cf6a46634d6b2765c40232b1bb1de3bcf55` from branch
`feat/3ds-support`.

That fork commit implements the in-tree `ctru_ndsp` backend designed in
`docs/3ds-backend-design.md`.

## Fork Changes

- Added `SoLoud::Soloud::CTRU_NDSP` and regenerated the C API enum as
  `SOLOUD_CTRU_NDSP = 14`.
- Added `ctru_ndsp_init` to the internal backend init declarations.
- Added `WITH_CTRU_NDSP` dispatch in `src/core/soloud.cpp`; `AUTO` can choose
  the backend when it is compiled in, and explicit `CTRU_NDSP` init returns the
  backend's error if setup fails.
- Added `src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp`.
- Added CMake/release metadata for the backend source.

## Backend Shape

The backend initializes NDSP, configures channel 0 for stereo signed 16-bit PCM
at 44100 Hz, and owns three linear-memory `ndspWaveBuf` buffers.

The backend creates its audio thread through SoLoud's C++ thread abstraction,
which is backed by libctru on 3DS in this fork. The thread only calls SoLoud C++
mixing and libctru NDSP APIs; it never enters the Nim runtime, so it remains
compatible with `--threads:off` Nim 3DS builds.

The refill loop mixes with `Soloud::mixSigned16`, flushes each filled wave
buffer with `DSP_FlushDataCache`, queues it with `ndspChnWaveBufAdd`, and sleeps
on a `LightEvent` signaled by the NDSP callback when no buffer is ready.

Cleanup stops the refill loop, joins/releases the thread, clears channel 0,
calls `ndspExit`, frees linear memory, and clears SoLoud backend data.

## Play Integration

`src/play/private/soloud_sources.nim` now compiles the headless `NOSOUND` and
`NULLDRIVER` backends for host builds, but switches to `WITH_CTRU_NDSP` plus
`backend/ctru_ndsp/soloud_ctru_ndsp.cpp` when `playPlatform3ds` is defined.

The 3DS toolchain flags, libctru include path, and libctru link libraries remain
owned by `nim_3ds.cfg`.

`src/play/backends.nim` now exposes `ctruNdspBackend` directly from the generated
raw constant under `playPlatform3ds`, and `platformDefaultBackend()` returns it
for 3DS builds.

## Verification

The fork backend was compiled directly with devkitARM/libctru:

```sh
/opt/devkitpro/devkitARM/bin/arm-none-eabi-g++ \
  -D__3DS__ \
  -DWITH_CTRU_NDSP \
  -Iinclude \
  -I/opt/devkitpro/libctru/include \
  -march=armv6k \
  -mtune=mpcore \
  -mfloat-abi=hard \
  -mtp=soft \
  -fno-exceptions \
  -fno-rtti \
  -std=gnu++11 \
  -c src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp \
  -o /tmp/soloud_ctru_ndsp.o
```

A devkitARM static archive was also built from the SoLoud core closure plus
`src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp`, producing
`/tmp/soloud-ctru-build/libsoloud_ctru_ndsp.a`.

After re-vendoring into `play`, the fork tracked-file list was compared against
`vendor/soloud/`.
