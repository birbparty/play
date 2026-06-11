# SoLoud Vendor Audit

This audit records the phase-1 integration state of the local birbparty SoLoud
fork intended for `play` vendoring.

## Fork Pin

- Local checkout: `~/git/soloud`
- Remote: `git@github.com:birbparty/soloud.git`
- Branch inspected: `feat/3ds-support`
- Commit inspected: `412011ec5c950ebf85f717b57722bb9298329686`
- Worktree status at audit time: clean; inspected commit matches the vendored
  snapshot recorded in `docs/soloud-vendor.md`

The original audit began from `e82fd32c1f62183922f08c14c814a02b58db1873`;
this document now tracks the current copied fork snapshot.

## Required Top-Level Files

The fork contains the expected zlib license and source layout for vendoring:

- `LICENSE`
- `include/soloud.h`
- `include/soloud_c.h`
- `include/soloud_thread.h`
- `include/soloud_wav.h`
- `include/soloud_wavstream.h`
- `include/soloud_bus.h`
- `src/c_api/soloud_c.cpp`
- `src/core/*.cpp`
- `src/backend/*/*.cpp`
- `src/audiosource/wav/*`
- `src/filter/*`

`include/soloud_c.h` and `src/c_api/soloud_c.cpp` are generated files. In this
fork, start with `scripts/makeglue.py` and `scripts/soloud_codegen.py` when
changing generated C API output. Do not edit generated files by hand; backend
enum additions must land in the fork's generator flow or be regenerated
consistently in the fork before re-vendoring.

## Backend Enum Values

`include/soloud.h` defines `SoLoud::Soloud::BACKENDS` in this order:

| C++ enum | C API enum | Value |
| --- | --- | ---: |
| `AUTO` | `SOLOUD_AUTO` | 0 |
| `SDL1` | `SOLOUD_SDL1` | 1 |
| `SDL2` | `SOLOUD_SDL2` | 2 |
| `PORTAUDIO` | `SOLOUD_PORTAUDIO` | 3 |
| `WINMM` | `SOLOUD_WINMM` | 4 |
| `XAUDIO2` | `SOLOUD_XAUDIO2` | 5 |
| `WASAPI` | `SOLOUD_WASAPI` | 6 |
| `ALSA` | `SOLOUD_ALSA` | 7 |
| `JACK` | `SOLOUD_JACK` | 8 |
| `OSS` | `SOLOUD_OSS` | 9 |
| `OPENAL` | `SOLOUD_OPENAL` | 10 |
| `COREAUDIO` | `SOLOUD_COREAUDIO` | 11 |
| `OPENSLES` | `SOLOUD_OPENSLES` | 12 |
| `VITA_HOMEBREW` | `SOLOUD_VITA_HOMEBREW` | 13 |
| `CTRU_NDSP` | `SOLOUD_CTRU_NDSP` | 14 |
| `MINIAUDIO` | `SOLOUD_MINIAUDIO` | 15 |
| `NOSOUND` | `SOLOUD_NOSOUND` | 16 |
| `NULLDRIVER` | `SOLOUD_NULLDRIVER` | 17 |
| `BACKEND_MAX` | `SOLOUD_BACKEND_MAX` | 18 |

The vendored fork now includes a 3DS / libctru / NDSP backend enum and matching
C API enum. See `docs/3ds-backend-impl.md` for the implementation record.

## Backend Inventory

Backends present under `src/backend/`:

- Desktop and common: `alsa`, `coreaudio`, `jack`, `miniaudio`, `openal`,
  `opensles`, `oss`, `portaudio`, `sdl`, `sdl_static`, `sdl2_static`, `wasapi`,
  `winmm`, `xaudio2`
- Test/headless: `nosound`, `null`
- Console/homebrew: `ctru_ndsp`, `vita_homebrew`

`src/core/soloud.cpp` has dispatch guarded by backend defines including
`WITH_CTRU_NDSP`, `WITH_VITA_HOMEBREW`, `WITH_NOSOUND`, `WITH_NULL`, and
`WITH_MINIAUDIO`.

`WITH_NULL` only initializes when explicitly requested as `NULLDRIVER`; it is
not an `AUTO` fallback. `WITH_NOSOUND` can participate in `AUTO` selection.

## Vita Backend Status

The fork includes `src/backend/vita_homebrew/soloud_vita_homebrew.cpp`.

Observed behavior from source inspection:

- Requires `WITH_VITA_HOMEBREW`.
- Includes VitaSDK headers `psp2/audioout.h` and `psp2/kernel/threadmgr.h`.
- Requires `aSamplerate == 44100` and `aChannels == 2`; otherwise returns
  `INVALID_PARAMETER`.
- Opens `SCE_AUDIO_OUT_PORT_TYPE_BGM` through `sceAudioOutOpenPort`.
- Allocates two signed 16-bit stereo buffers sized by `aChannels * aBuffer`.
- Calls `postinit_internal(aSamplerate, data->samples * aChannels, aFlags,
  aChannels)`.
- Creates a Vita kernel thread named `soloud audio output`.
- The thread repeatedly calls `Soloud::mixSigned16()` and submits buffers with
  `sceAudioOutOutput()`.
- Cleanup waits for and deletes the Vita thread, releases the audio port, frees
  both buffers, and clears `mBackendData`.

Gaps to verify in the Vita evaluation bead:

- Actual VitaSDK compile and link flags for C++ and `SceAudioOut`.
- Whether `memset` on `VitaData`, which contains `std::atomic<bool>`, needs a
  fork fix.
- Behavior for default `AUTO` samplerate/buffer values, because this backend
  rejects non-44100/non-stereo parameters.
- Whether shutdown remains clean if thread creation or buffer allocation fails.

Default `Soloud::init()` currently dispatches with 44100 Hz and 2 channels
before calling the Vita backend; explicit non-44100 or non-stereo init should
still be treated as unsupported until the Vita evaluation bead proves otherwise.

## 3DS Backend Status

The fork includes `src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp`, the
`SOLOUD_CTRU_NDSP` C API enum, and `WITH_CTRU_NDSP` dispatch in
`src/core/soloud.cpp`.

The backend initializes NDSP, owns linear-memory wave buffers, and creates a
C++/libctru audio thread that calls SoLoud mixing without entering the Nim
runtime. The real hardware `dspfirm.cdc` prerequisite remains documented in
`docs/3ds-backend-design.md`.

The documented NULLDRIVER plus explicit pump approach remains a fallback only.
It does not provide the same backend-owned thread and mutex behavior as a real
in-tree backend.

## Thread Implementation

`include/soloud_thread.h` exposes:

- mutex creation/destruction/lock/unlock
- `createThread`, `wait`, `release`, and `sleep`
- a small thread pool abstraction

`src/core/soloud_thread.cpp` currently has three implementations:

- Windows: `CRITICAL_SECTION` and `CreateThread`
- 3DS: libctru `LightLock`, `threadCreate`, `threadJoin`, `svcSleepThread`, and
  `osGetTime`
- Everything else: pthreads (`pthread_mutex_t`, `pthread_create`,
  `pthread_join`, `nanosleep`, `clock_gettime`)

The libctru implementation is required because devkitARM does not provide
pthreads in the target environment expected by this project.

## C API Availability For Phase 1

The generated C API exposes the key phase-1 symbols:

- Engine lifecycle, backend metadata, and master volume:
  `Soloud_create`, `Soloud_destroy`, `Soloud_init`, `Soloud_initEx`,
  `Soloud_deinit`, `Soloud_getErrorString`, `Soloud_getBackendId`,
  `Soloud_getBackendString`, `Soloud_getBackendSamplerate`,
  `Soloud_getBackendBufferSize`, `Soloud_setGlobalVolume`
- Playback and handles:
  `Soloud_play`, `Soloud_playEx`, `Soloud_playBackground`,
  `Soloud_playBackgroundEx`, `Soloud_stop`, `Soloud_stopAll`,
  `Soloud_setPause`, `Soloud_setLooping`, `Soloud_setVolume`,
  `Soloud_isValidVoiceHandle`, `Soloud_setMaxActiveVoiceCount`
- Fades and scheduling:
  `Soloud_fadeVolume`, `Soloud_fadeGlobalVolume`, `Soloud_schedulePause`,
  `Soloud_scheduleStop`
- Manual mixing fallback:
  `Soloud_mixSigned16`
- Buses:
  `Bus_create`, `Bus_destroy`, `Bus_play`, `Bus_playEx`, `Bus_setVolume`,
  `Bus_stop`
- Resident assets:
  `Wav_create`, `Wav_destroy`, `Wav_load`, `Wav_loadMem`,
  `Wav_setLooping`, `Wav_setVolume`, `Wav_stop`
- Streaming assets:
  `WavStream_create`, `WavStream_destroy`, `WavStream_load`,
  `WavStream_loadMem`, `WavStream_loadToMem`, `WavStream_setLooping`,
  `WavStream_setVolume`, `WavStream_stop`

This is enough for the phase-1 `play` wrapper surface: lifecycle, WAV/OGG
resident sounds, streamed music, handles, fixed buses, volume control, fades,
and stop-after-fade scheduling.

## Initial Compile-Unit Inventory

The generated `src/c_api/soloud_c.cpp` wraps the full generated SoLoud C API,
not only the phase-1 `play` surface. It includes wrappers for filters and
non-WAV audio sources such as `Ay`, `Monotone`, `Noise`, `Openmpt`, `Queue`,
`Sfxr`, `Speech`, `TedSid`, `Vic`, and `Vizsn`.

The compile-model bead must choose and verify one of these models:

1. Compile a broad generated-C-API closure:
   - `src/c_api/soloud_c.cpp`
   - all `src/core/*.cpp`
   - selected backend files such as `src/backend/null/soloud_null.cpp`,
     `src/backend/nosound/soloud_nosound.cpp`, and
     `src/backend/miniaudio/soloud_miniaudio.cpp`
   - `src/filter/*.cpp`
   - `src/audiosource/wav/soloud_wav.cpp`
   - `src/audiosource/wav/soloud_wavstream.cpp`
   - `src/audiosource/wav/dr_impl.cpp`
   - `src/audiosource/wav/stb_vorbis.c`
   - generated-wrapper audio source implementations referenced by
     `soloud_c.cpp`, including `src/audiosource/ay/*.cpp`,
     `src/audiosource/monotone/soloud_monotone.cpp`,
     `src/audiosource/noise/soloud_noise.cpp`,
     `src/audiosource/sfxr/soloud_sfxr.cpp`,
     `src/audiosource/speech/*.cpp`, `src/audiosource/tedsid/*.cpp`,
     `src/audiosource/vic/soloud_vic.cpp`, and
     `src/audiosource/vizsn/soloud_vizsn.cpp`
   - an explicit `openmpt` decision: either compile the OpenMPT wrapper and
     satisfy its library requirements, or regenerate/prune the C API so OpenMPT
     wrappers are not emitted.
2. Regenerate or maintain a reduced C API in the SoLoud fork for the phase-1
   wrapper surface before vendoring. Under this model, the reduced
   `soloud_c.cpp` must not define wrappers for omitted SoLoud types.

Do not treat a small WAV/core/backend source list as link-verified with the
unmodified generated `soloud_c.cpp`. The compile-model bead must prove the
chosen source closure with the Nim `{.compile.}` flow.

Console-specific additions:

- Vita: `src/backend/vita_homebrew/soloud_vita_homebrew.cpp` plus VitaSDK
  compile/link flags.
- 3DS: `ctru_ndsp` is present under `WITH_CTRU_NDSP`.

Avoid compiling optional sources that require unavailable third-party libraries
unless a later bead explicitly enables that feature, for example OpenMPT or
dynamic OpenAL/PortAudio loader code.

## Phase-1 Gaps

- Vita backend exists but still needs a real VitaSDK compile/evaluation pass.
- `soloud_c.h` is generated; any backend enum changes must be regenerated in
  the fork rather than patched only in `play`.
- Future 3DS work still needs example cross-compiles and real hardware
  verification.
