# SoLoud Vita Backend Evaluation

This evaluates the existing `vita_homebrew` backend in the vendored
birbparty/soloud snapshot for `play-eo8`.

## Snapshot

- Reference checkout: `~/git/soloud` at
  `412011ec5c950ebf85f717b57722bb9298329686`
- Evaluated tree: `vendor/soloud/`, using the vendored files from that fork
  snapshot
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

A broader static archive was built from `soloud_c.cpp`, the SoLoud core closure
currently mirrored by `src/play/private/soloud_sources.nim`, and
`vita_homebrew` in place of the host headless backends:

```sh
/tmp/play-soloud-vita-build/libsoloud_vita_homebrew.a
```

The archive size was about 257 KiB. The archive contained:

```text
vendor_soloud_src_backend_vita_homebrew_soloud_vita_homebrew_cpp.o
vendor_soloud_src_c_api_soloud_c_cpp.o
vendor_soloud_src_core_soloud_audiosource_cpp.o
vendor_soloud_src_core_soloud_bus_cpp.o
vendor_soloud_src_core_soloud_core_3d_cpp.o
vendor_soloud_src_core_soloud_core_basicops_cpp.o
vendor_soloud_src_core_soloud_core_faderops_cpp.o
vendor_soloud_src_core_soloud_core_filterops_cpp.o
vendor_soloud_src_core_soloud_core_getters_cpp.o
vendor_soloud_src_core_soloud_core_setters_cpp.o
vendor_soloud_src_core_soloud_core_voicegroup_cpp.o
vendor_soloud_src_core_soloud_core_voiceops_cpp.o
vendor_soloud_src_core_soloud_cpp.o
vendor_soloud_src_core_soloud_fader_cpp.o
vendor_soloud_src_core_soloud_fft_cpp.o
vendor_soloud_src_core_soloud_fft_lut_cpp.o
vendor_soloud_src_core_soloud_file_cpp.o
vendor_soloud_src_core_soloud_filter_cpp.o
vendor_soloud_src_core_soloud_misc_cpp.o
vendor_soloud_src_core_soloud_queue_cpp.o
vendor_soloud_src_core_soloud_thread_cpp.o
```

## Link Status

A minimal executable that initializes `SoLoud::Soloud::VITA_HOMEBREW` initially
failed to link with the pre-`-lpthread` `nim_vita.cfg`-style library set because
pthread symbols were unresolved from both libstdc++ and SoLoud's generic thread
implementation.

The smoke object was built from:

```cpp
#include "soloud.h"

int main() {
  SoLoud::Soloud soloud;
  return soloud.init(SoLoud::Soloud::CLIP_ROUNDOFF,
                     SoLoud::Soloud::VITA_HOMEBREW,
                     44100,
                     2048,
                     2);
}
```

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

This is reflected in the current `nim_vita.cfg` link group, with `-lpthread`
inside the `--start-group` / `--end-group` runtime set, next to `-lstdc++`.

Artifact hashes from this evaluation:

```text
e4143542feeb98a0d48800a9f1a67a887fd22d3d3ab0e4a203aef68643deb650  /tmp/play-soloud-vita-build/libsoloud_vita_homebrew.a
36d5351cb1bf18c2a090c64c8663ee6f2b6e096a57a61fe7ff4a98dc56c94ac1  /tmp/play_vita_link_smoke.elf
```

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

`src/play/private/soloud_sources.nim` now compiles `WITH_VITA_HOMEBREW` and
`backend/vita_homebrew/soloud_vita_homebrew.cpp` when `playPlatformVita` is
defined. Vita builds no longer compile the host `NOSOUND`/`NULLDRIVER` backend
closure.

`nim_vita.cfg` now includes `-lpthread` inside the grouped VitaSDK runtime
libraries. `scripts/build_vita_examples.sh` copies that cfg into place, rewrites
the default VitaSDK root when `VITASDK` is set, builds each example with
`nim c -d:vita`, and packages the resulting ELF into a `.vpk`.

See `docs/vita-build.md` for the current example build and packaging flow.

## Conclusion

The existing SoLoud `vita_homebrew` backend builds under VitaSDK as-is. No
birbparty/soloud fork fix or re-vendor was required for this evaluation.

Runtime caveat: the backend currently returns `INVALID_PARAMETER` unless
`aSamplerate == 44100` and `aChannels == 2`, so Play's Vita integration should
keep defaults aligned or validate overrides before calling `Soloud_initEx`.

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
