# SoLoud Vendor Audit

This audit records the phase-1 integration state of the local birbparty SoLoud
fork intended for `play` vendoring.

## Fork Pin

- Local checkout: `~/git/soloud`
- Remote: `git@github.com:birbparty/soloud.git`
- Branch inspected: `feat/3ds-support`
- Commit inspected: `e82fd32c1f62183922f08c14c814a02b58db1873`
- Worktree status at audit time: clean against `origin/master`

Use this commit as the initial audit reference only. The vendoring bead should
record the exact commit that is copied into `vendor/soloud/`.

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

`include/soloud_c.h` and `src/c_api/soloud_c.cpp` are generated files. Do not
edit them by hand; backend enum additions must land in the fork's generator
flow or be regenerated consistently in the fork before re-vendoring.

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
| `MINIAUDIO` | `SOLOUD_MINIAUDIO` | 14 |
| `NOSOUND` | `SOLOUD_NOSOUND` | 15 |
| `NULLDRIVER` | `SOLOUD_NULLDRIVER` | 16 |
| `BACKEND_MAX` | `SOLOUD_BACKEND_MAX` | 17 |

There is no 3DS / libctru / NDSP backend enum yet. Adding one requires updates
to `include/soloud.h`, `include/soloud_c.h`, `src/core/soloud.cpp`, backend
source files, and the C API generation path.

## Backend Inventory

Backends present under `src/backend/`:

- Desktop and common: `alsa`, `coreaudio`, `jack`, `miniaudio`, `openal`,
  `opensles`, `oss`, `portaudio`, `sdl`, `sdl_static`, `sdl2_static`, `wasapi`,
  `winmm`, `xaudio2`
- Test/headless: `nosound`, `null`
- Console/homebrew: `vita_homebrew`

`src/core/soloud.cpp` has dispatch guarded by backend defines including
`WITH_VITA_HOMEBREW`, `WITH_NOSOUND`, `WITH_NULL`, and `WITH_MINIAUDIO`.

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

## 3DS Backend Status

No 3DS backend directory was found under `src/backend/`, and no C API enum value
exists for a 3DS backend.

Required fork work before `play` can select a real 3DS backend:

- Add a backend directory such as `src/backend/ctru_ndsp/`.
- Add a C++ enum entry in `include/soloud.h`.
- Regenerate or update `include/soloud_c.h` with the matching `SOLOUD_*` enum.
- Add dispatch in `src/core/soloud.cpp`, guarded by a define such as
  `WITH_CTRU_NDSP`.
- Implement NDSP initialization, wave-buffer ownership, and a C++/libctru audio
  thread that calls SoLoud mixing without entering the Nim runtime.
- Document the real hardware `dspfirm.cdc` prerequisite in `play`.

The documented NULLDRIVER plus explicit pump approach remains a fallback only.
It does not provide the same backend-owned thread and mutex behavior as a real
in-tree backend.

## Thread Implementation

`include/soloud_thread.h` exposes:

- mutex creation/destruction/lock/unlock
- `createThread`, `wait`, `release`, and `sleep`
- a small thread pool abstraction

`src/core/soloud_thread.cpp` currently has two implementations:

- Windows: `CRITICAL_SECTION` and `CreateThread`
- Everything else: pthreads (`pthread_mutex_t`, `pthread_create`,
  `pthread_join`, `nanosleep`, `clock_gettime`)

There is no libctru implementation. This is a blocking 3DS gap because devkitARM
does not provide pthreads in the target environment expected by this project.
The 3DS thread-port bead should add libctru mutex/thread/sleep/time support in
the SoLoud fork before the 3DS NDSP backend implementation.

## C API Availability For Phase 1

The generated C API exposes the key phase-1 symbols:

- Engine lifecycle and backend metadata:
  `Soloud_create`, `Soloud_destroy`, `Soloud_init`, `Soloud_initEx`,
  `Soloud_deinit`, `Soloud_getErrorString`, `Soloud_getBackendId`,
  `Soloud_getBackendString`, `Soloud_getBackendSamplerate`,
  `Soloud_getBackendBufferSize`
- Playback and handles:
  `Soloud_play`, `Soloud_playEx`, `Soloud_playBackground`,
  `Soloud_playBackgroundEx`, `Soloud_stop`, `Soloud_stopAll`,
  `Soloud_setPause`, `Soloud_setLooping`, `Soloud_setVolume`,
  `Soloud_isValidVoiceHandle`, `Soloud_setMaxActiveVoiceCount`
- Fades and scheduling:
  `Soloud_fadeVolume`, `Soloud_fadeGlobalVolume`, `Soloud_schedulePause`,
  `Soloud_scheduleStop`
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

The vendoring and compile-model beads should start with this conservative
host/headless set:

- `src/c_api/soloud_c.cpp`
- all `src/core/*.cpp`
- `src/backend/null/soloud_null.cpp`
- `src/backend/nosound/soloud_nosound.cpp`
- `src/backend/miniaudio/soloud_miniaudio.cpp` for desktop
- `src/audiosource/wav/soloud_wav.cpp`
- `src/audiosource/wav/soloud_wavstream.cpp`
- `src/audiosource/wav/dr_impl.cpp`
- `src/audiosource/wav/stb_vorbis.c`
- `src/filter/*.cpp` as needed once filters are exposed or linked through
  generated C API references

Console-specific additions:

- Vita: `src/backend/vita_homebrew/soloud_vita_homebrew.cpp` plus VitaSDK
  compile/link flags.
- 3DS: not present yet; add the future `ctru_ndsp` backend after fork work.

Avoid compiling optional sources that require unavailable third-party libraries
unless a later bead explicitly enables that feature, for example OpenMPT or
dynamic OpenAL/PortAudio loader code.

## Phase-1 Gaps

- No 3DS backend enum, dispatch, or backend directory exists yet.
- `soloud_thread.cpp` falls back to pthreads on non-Windows targets; it needs a
  libctru implementation for 3DS.
- Vita backend exists but still needs a real VitaSDK compile/evaluation pass.
- `soloud_c.h` is generated; any backend enum changes must be regenerated in
  the fork rather than patched only in `play`.
- The final vendored snapshot SHA may differ from this audit SHA after required
  Vita/3DS fork changes.
