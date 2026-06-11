# 3DS NDSP SoLoud Backend Design

This spike confirms the architecture for a real Nintendo 3DS backend in the
birbparty SoLoud fork. The backend should live in the fork first, then be
re-vendored into `play`.

## Decision

Implement an in-tree SoLoud backend named `ctru_ndsp` that mixes SoLoud at
44100 Hz into stereo signed 16-bit buffers and submits those buffers to one NDSP
channel.

NDSP itself exposes `NDSP_SAMPLE_RATE` as `SYSCLOCK_SOC / 512.0`, which is about
32728.5 Hz with the installed libctru headers. That does not disprove the 44100
Hz SoLoud target: libctru exposes `ndspChnSetRate(int id, float rate)`, and the
devkitPro audio examples use application-selected rates through that API. The
backend should set channel 0 to `44100.0f` and let NDSP resample to its hardware
output cadence.

Use this backend shape:

- SoLoud init defaults: `samplerate = 44100`, `channels = 2`.
- Reject non-stereo init for the first backend pass with `INVALID_PARAMETER`.
- Configure NDSP with `NDSP_OUTPUT_STEREO`.
- Configure channel 0 with `NDSP_FORMAT_STEREO_PCM16`.
- Use `Soloud::mixSigned16()` so the backend writes interleaved `s16` stereo
  samples directly into NDSP wave buffers.
- Allocate wave-buffer sample memory from linear memory, not regular heap
  memory.
- Flush each filled buffer with `DSP_FlushDataCache` before queueing it with
  `ndspChnWaveBufAdd`.

## Hardware Prerequisite

3DS homebrew audio requires DSP firmware at `sdmc:/3ds/dspfirm.cdc` on real
hardware. The installed devkitPro audio example README documents obtaining it
through Luma3DS Rosalina: "Miscellaneous options..." then "Dump DSP firmware".

Citra uses high-level DSP emulation; devkitPro notes that a zero-byte
`dspfirm.cdc` is sufficient there. Do not treat a Citra-only pass as hardware
verification.

## Buffering Model

Use a small ring of NDSP wave buffers owned by the backend:

- Start with 3 wave buffers, matching the threaded Opus/Vorbis examples.
- Start with 120 ms per buffer for implementation simplicity and underrun
  tolerance: `samplesPerBuffer = samplerate * 120 / 1000`, or 5292 samples at
  44100 Hz.
- Memory per buffer: `samplesPerBuffer * 2 * sizeof(s16)`, about 21168 bytes.
- Total sample memory for 3 buffers: about 63504 bytes, allocated with
  `linearAlloc`.

This is conservative for the first backend. After hardware profiling, a later
performance bead can reduce latency by testing smaller buffers such as 20-40 ms.

Backend data should hold:

- `Soloud *soloud`
- `Thread::ThreadHandle thread`
- `ndspWaveBuf waveBufs[3]`
- one contiguous `s16 *samples` allocation for all wave buffers
- `LightEvent refillEvent`
- an atomic or volatile quit flag
- `unsigned int samplerate`, `samplesPerBuffer`, and `channels`

The audio thread should:

1. Prime all wave buffers before playback starts.
2. Loop until quit is requested.
3. Find `NDSP_WBUF_DONE` or initially free buffers.
4. Call `soloud->mixSigned16(buffer, samplesPerBuffer)`.
5. Flush `samplesPerBuffer * channels * sizeof(s16)` bytes with
   `DSP_FlushDataCache`.
6. Queue the buffer with `ndspChnWaveBufAdd(0, &waveBuf)`.
7. Sleep on a `LightEvent` signaled by `ndspSetCallback` when no buffers are
   ready.

Cleanup should set the quit flag, signal the event, wait/release the thread,
clear channel 0 with `ndspChnWaveBufClear` or `ndspChnReset`, call `ndspExit`,
free linear memory, delete backend data, and clear `mBackendData`.

## SoLoud Fork Patch List

Patch these exact files in `~/git/soloud`:

- `include/soloud.h`
  - Add `CTRU_NDSP` to `SoLoud::Soloud::BACKENDS`.
  - Keep `BACKEND_MAX` last.
- `src/tools/codegen/main.cpp`
  - Build and run the C API generator after the enum changes.
- `include/soloud_c.h`
  - Generated output must include `SOLOUD_CTRU_NDSP`.
- `src/c_api/soloud_c.cpp`
  - Regenerate with the rest of the C API output if the generator touches it.
- `src/c_api/soloud.def`
  - Regenerate with the rest of the C API output if the generator touches it.
- `scripts/soloud_codegen.py`
  - Regenerate with the rest of the C API output if the generator touches it.
- `src/core/soloud.cpp`
  - Declare `ctru_ndsp_init`.
  - Add `WITH_CTRU_NDSP` to the top-level "no backend defined" preprocessor
    guard.
  - Add a `WITH_CTRU_NDSP` guarded dispatch block.
  - Allow `AUTO` to choose this backend when compiled for 3DS.
  - Set `mBackendID = Soloud::CTRU_NDSP` and backend string from the backend.
- `src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp`
  - Implement `ctru_ndsp_init`, backend data, audio thread, NDSP setup, buffer
    filling, and cleanup.
  - On successful init, set `aSoloud->mBackendData`,
    `aSoloud->mBackendCleanupFunc`, and `aSoloud->mBackendString`.
  - Call `aSoloud->postinit_internal(samplerate, samplesPerBuffer * channels,
    aFlags, channels)` before returning success.
- `contrib/Configure.cmake`
  - Add a `SOLOUD_BACKEND_CTRU_NDSP` option if CMake builds should expose the
    backend.
- `contrib/src.cmake`
  - Add `src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp` and `-DWITH_CTRU_NDSP`
    behind the CMake option.
- `scripts/makerel.py`
  - Add the new backend source to release/source sanity lists if the fork's
    release tooling should package it.

Patch these files in `play` after re-vendoring:

- `vendor/soloud/**`
  - Refresh from the fork commit that contains the backend.
- `docs/soloud-vendor.md`
  - Record the new fork commit SHA.
- `src/play/private/soloud_sources.nim`
  - Under `playPlatform3ds`, pass `-DWITH_CTRU_NDSP`, include libctru headers,
    link libctru as required by the 3DS build, and compile
    `backend/ctru_ndsp/soloud_ctru_ndsp.cpp`.
- `src/play/bindings/soloud_raw.nim`
  - Add `SOLOUD_CTRU_NDSP` after the regenerated C header confirms the enum
    value.
- `src/play/backends.nim`
  - Replace the temporary `playCtruNdspBackendId` intdefine path with the real
    raw constant.
- `tests/bindings/test_soloud_raw.nim` and `tests/bindings/test_backends.nim`
  - Update backend enum assertions after `BACKEND_MAX` changes.

## Open Questions For Implementation

- Whether the first backend should use `ndspSetCallback` plus `LightEvent` or a
  timed sleep loop. Prefer callback/event because devkitPro decoding examples
  use it to refill buffers after NDSP frames.
- Whether `ndspInit` failure should map to `INVALID_PARAMETER` or
  `UNKNOWN_ERROR`. Prefer `UNKNOWN_ERROR` unless the failure is a rejected
  SoLoud init argument.
- Whether default `AUTO` should choose `CTRU_NDSP` only when `WITH_CTRU_NDSP` is
  set, or also require `__3DS__`. Prefer both guards to avoid accidental host
  selection in cross-compiled source checks.
- Whether smaller buffers are stable on Old 3DS. Keep the first implementation
  conservative and require hardware profiling before reducing latency.

## Evidence Checked

- `/opt/devkitpro/libctru/include/3ds/ndsp/ndsp.h`
- `/opt/devkitpro/libctru/include/3ds/ndsp/channel.h`
- `/opt/devkitpro/libctru/include/3ds/services/dsp.h`
- `/opt/devkitpro/examples/3ds/audio/README.md`
- `/opt/devkitpro/examples/3ds/audio/streaming/source/main.c`
- `/opt/devkitpro/examples/3ds/audio/opus-decoding/source/main.c`
- `/opt/devkitpro/examples/3ds/audio/ogg-vorbis-decoding/source/main.c`
- `~/git/soloud/include/soloud.h`
- `~/git/soloud/include/soloud_c.h`
- `~/git/soloud/src/core/soloud.cpp`
- `~/git/soloud/src/backend/vita_homebrew/soloud_vita_homebrew.cpp`
- `~/git/soloud/src/backend/nosound/soloud_nosound.cpp`
