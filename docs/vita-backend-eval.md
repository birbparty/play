# SoLoud Vita Backend Evaluation

This evaluates the existing `vita_homebrew` backend in the vendored
birbparty/soloud snapshot for `play-eo8`.

## Snapshot

- Source checkout: `~/git/soloud`
- Vendored snapshot: `vendor/soloud/`
- Fork commit evaluated through vendor: `412011ec5c950ebf85f717b57722bb9298329686`
- Backend source: `vendor/soloud/src/backend/vita_homebrew/soloud_vita_homebrew.cpp`

No SoLoud fork patch was required for this evaluation, so `vendor/soloud/` was
not refreshed during this iteration.

## Compile Status

The backend source compiles with the installed VitaSDK toolchain:

```sh
/usr/local/vitasdk/bin/arm-vita-eabi-g++ \
  -DWITH_VITA_HOMEBREW \
  -Ivendor/soloud/include \
  -I/usr/local/vitasdk/arm-vita-eabi/include \
  -fno-exceptions \
  -fno-rtti \
  -std=gnu++11 \
  -c vendor/soloud/src/backend/vita_homebrew/soloud_vita_homebrew.cpp \
  -o /tmp/play_vita_homebrew.o
```

The required core pieces also compile with the same flags:

- `vendor/soloud/src/core/soloud.cpp`
- `vendor/soloud/src/core/soloud_thread.cpp`

A broader static archive was built from `soloud_c.cpp`, the SoLoud core closure,
and `vita_homebrew`:

```sh
/tmp/play-soloud-vita-build/libsoloud_vita_homebrew.a
```

The archive size was about 257 KiB.

## Link Status

A minimal executable that initializes `SoLoud::Soloud::VITA_HOMEBREW` failed to
link with the current `nim_vita.cfg`-style library set because pthread symbols
were unresolved from both libstdc++ and SoLoud's generic thread implementation.

The missing symbols included:

- `pthread_mutex_init`
- `pthread_mutex_destroy`
- `pthread_mutex_lock`
- `pthread_mutex_unlock`
- `pthread_create`
- `pthread_join`

Adding `-lpthread` to the grouped VitaSDK runtime libraries fixed the link:

```sh
/usr/local/vitasdk/bin/arm-vita-eabi-g++ \
  /tmp/play_vita_link_smoke.o \
  /tmp/play-soloud-vita-build/libsoloud_vita_homebrew.a \
  -Wl,-q \
  -L/usr/local/vitasdk/arm-vita-eabi/lib \
  -lSceAudio_stub \
  -Wl,--start-group \
  -lc -lm -lstdc++ -lpthread \
  -lSceLibKernel_stub \
  -lSceKernelThreadMgr_stub \
  -lSceIofilemgr_stub \
  -lSceProcessmgr_stub \
  -Wl,--end-group \
  -o /tmp/play_vita_link_smoke.elf
```

The linked smoke ELF was produced at `/tmp/play_vita_link_smoke.elf`.

## Warnings

The backend compiles cleanly without `-Wall`. With `-Wall -Wextra`, VitaSDK GCC
15.2.0 reports:

- `vita_thread` has an unused `args` parameter.
- `VitaData` is zeroed with `memset` even though it contains `std::atomic<bool>`.

The `memset` warning is already noted in the backend source. It did not block
the VitaSDK compile/link evaluation, but it should be fixed if a later bead
patches this backend in the fork.

## Play Integration Findings

`src/play/backends.nim` already selects `vitaHomebrewBackend` as
`platformDefaultBackend()` when `playPlatformVita` is defined.

`src/play/private/soloud_sources.nim` does not yet compile
`WITH_VITA_HOMEBREW` or `backend/vita_homebrew/soloud_vita_homebrew.cpp` for
`playPlatformVita`; Vita currently falls through to the host headless
`NOSOUND`/`NULLDRIVER` compile closure. A future Vita integration/build bead
should switch the Vita source closure to the real backend and add `-lpthread` to
the Vita link group.

## Conclusion

The existing SoLoud `vita_homebrew` backend builds under VitaSDK as-is. No
birbparty/soloud fork fix or re-vendor was required for this evaluation.

Required link libraries for a real Vita backend link are:

- `-lSceAudio_stub`
- `-lc`
- `-lm`
- `-lstdc++`
- `-lpthread`
- `-lSceLibKernel_stub`
- `-lSceKernelThreadMgr_stub`
- `-lSceIofilemgr_stub`
- `-lSceProcessmgr_stub`
