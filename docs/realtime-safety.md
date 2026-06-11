# Real-Time Safety and Thread-Safety

This audit covers the phase-1 public API and the vendored SoLoud integration.
The goal is to keep Nim code out of platform audio callbacks and document where
thread-safety depends on SoLoud backend behavior.

## Audio Thread Boundary

The public `play` API calls into SoLoud through generated C symbols imported in
`src/play/bindings/soloud_raw.nim`. Those imports are one-way calls from Nim into
C/C++; the wrapper does not export Nim callbacks, proc variables, or closures to
SoLoud.

Platform audio callbacks live in vendored C++ backend code:

- 3DS: `vendor/soloud/src/backend/ctru_ndsp/soloud_ctru_ndsp.cpp`
- Vita: `vendor/soloud/src/backend/vita_homebrew/soloud_vita_homebrew.cpp`
- desktop hardware backends, when enabled: C++ backend files under
  `vendor/soloud/src/backend/`

Those callbacks and backend worker threads call SoLoud mixer methods such as
`SoLoud::Soloud::mixSigned16` or `SoLoud::Soloud::mix` directly. They do not
call back into Nim, allocate Nim objects, or enter the Nim runtime. The 3DS NDSP
callback only signals a `LightEvent`; the dedicated C++ backend thread performs
mixing and NDSP buffer submission.

## Public API Threading Model

Application code may call the public API from the game/application thread:

- lifecycle: `init`, `shutdown`, `withPlay`
- asset loading and disposal: `loadSound`, `loadMusic`, `dispose`
- playback and handle controls: `play`, `playMusic`, `pause`, `resume`,
  `stop`, `setLooping`, `setVolume`
- bus controls and fades: `setMasterVolume`, fixed bus volume setters,
  `fadeVolume`, `fadeInMusic`, `fadeOutMusic`

These functions may allocate Nim wrapper objects, perform filesystem I/O, and
raise or return typed errors. They are not real-time functions and must not be
called from a platform audio callback.

Once initialized with a real backend, SoLoud protects engine operations with
its backend audio mutex. Headless host tests currently use `NULLDRIVER` and
`NOSOUND`; those paths are suitable for deterministic CI behavior but should not
be treated as proof of platform hardware scheduling or latency.

## Shutdown and Ownership

Wrapper shutdown is ordered to stop active voices before destroying fixed buses
and deinitializing the engine. Asset disposal is idempotent and stops the
underlying SoLoud source before destroying it. Tests cover:

- repeated load/play/stop/shutdown/reinit cycles
- shutdown while voices are active, followed by asset disposal
- failed loads followed by later successful init/load/play

Native heap leak detection is outside the current CI scope. The stress tests are
behavioral checks for wrapper state, handle validity, and crash-free cleanup.

## Remaining Constraints

- Do not expose Nim callbacks, closures, or proc variables to SoLoud backend
  code without a separate real-time safety review.
- Do not call `loadSound`, `loadMusic`, `dispose`, or any public wrapper API
  from platform audio callbacks.
- Keep platform audio backend work in C/C++ code that only invokes SoLoud mixer
  operations and platform APIs.
- Host hardware audio backends are not currently enabled in the Nim source
  closure; current host verification proves headless behavior only.
- If a future manual-pump path uses `Soloud_mixSigned16` from the game loop, it
  is single-threaded by construction and must document that it is not equivalent
  to a platform audio callback.
