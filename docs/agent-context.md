# play Agent Context

This document is the implementation context for phase 1 of `play`, a Nim audio
library for games built on the birbparty fork of SoLoud. It summarizes the
local design documents into the scope agents should execute now, and separates
that scope from future middleware work.

## Source Documents

- `docs/ROADMAP.md` is the current roadmap and scope authority.
- `docs/prompts/nim-audio-library-for-game-development-built-on-soloud.md`
  is the detailed phase-1 task-graph prompt.
- `docs/soloud.md` explains the SoLoud adoption strategy, three-layer binding
  architecture, and platform risks.
- `docs/clean-room1.md`, `docs/clean-room2.md`, and `docs/clean-room3.md`
  describe the larger long-term middleware vision. Use them for architectural
  direction only; do not treat their larger feature sets or repository layouts
  as phase-1 requirements.

If source documents conflict, the roadmap and phase-1 task-graph prompt
supersede older phase numbering, target lists, and repository layouts in
`docs/soloud.md` and `docs/clean-room*.md`.

## Phase-1 Product Scope

Phase 1 ships a small, Nim-first playback library named `play`. Game code
imports `play`, not SoLoud bindings, and uses the same public API on desktop,
Nintendo 3DS homebrew, and PS Vita homebrew.

The committed phase-1 public API surface is:

- Lifecycle: `init()` and `shutdown()` with clean shutdown ordering.
- Assets: `loadSound(path)` for resident SFX and `loadMusic(path)` for streamed
  music. WAV and OGG are required.
- Playback: `play(sound) -> Handle`, optionally routed to a fixed bus, and
  `playMusic(music) -> Handle`.
- Handles: pause, resume, stop, looping, per-handle volume, and cheap validity
  checks for live, stopped, dead, or stolen handles.
- Buses: fixed `music`, `sfx`, and `ui` buses routed to master. Phase 1 exposes
  `setMasterVolume`, `setMusicVolume`, `setSfxVolume`, and `setUiVolume`; it
  does not expose public bus creation, mute, solo, metering, or arbitrary
  routing.
- Fades: `fadeVolume(handle, target, seconds)`, `fadeInMusic`, and
  `fadeOutMusic`, including stop-after-fade behavior where appropriate.

Out of scope for phase 1: WASM, clckr-side integration, public event/parameter
systems, adaptive music graphs, authoring tools, profiler/live-debug tooling,
plugin SDK, arbitrary DSP graph authoring, spatial audio, user-created buses,
and additional codec exposure beyond phase-1 WAV/OGG.

## Architecture

Use the three-layer architecture from the design docs:

1. Raw bindings over `soloud_c.h`.
2. A safe wrapper that owns SoLoud lifecycle, assets, handles, errors, and
   shutdown ordering.
3. The top-level Nim-first `play` API in `src/play.nim`.

The raw layer may be generated or handwritten, but that decision belongs to the
Futhark-versus-handwritten spike. Consumers must never need libclang or binding
generation at install time.

The implementation must use Nim's C backend (`nim c`). SoLoud's C++ sources are
compiled through Nim `{.compile.}` pragmas, with `soloud_c.cpp` as the
`extern "C"` boundary. Do not require `nim cpp`.

Keep raw bindings and wrapper internals importable by implementation modules,
but do not make game code depend on raw SoLoud pointers, C voice ids, C API
symbols, or platform-specific backends.

## SoLoud Fork Policy

`play` vendors a pinned snapshot of the birbparty SoLoud fork from
`~/git/soloud` / `github.com/birbparty/soloud`. The vendored copy lives under
`vendor/soloud/`.

Rules for agents:

- Do not edit `vendor/soloud/` directly as the source of truth.
- Backend fixes, `soloud_thread` work, C API enum changes, and Vita or 3DS
  patches land in the birbparty SoLoud fork first.
- Re-vendor from a documented fork commit SHA after fork changes are committed.
- Preserve SoLoud license files and document the exact vendored SHA.

SoLoud is zlib-licensed and compatible with commercial games. Keep all project
code, fixtures, and generated assets under permissive terms. Do not redistribute
proprietary SDK material.

## Platform Targets

Phase 1 targets:

- Windows, Linux, and macOS using existing SoLoud desktop backends, with
  miniaudio preferred when practical.
- Nintendo 3DS homebrew using devkitARM/libctru/NDSP. The intended path is an
  in-tree SoLoud backend in the birbparty fork, modeled on `vita_homebrew`.
- PS Vita homebrew using VitaSDK/AudioOut. Evaluate the existing SoLoud
  `vita_homebrew` backend before designing replacement work.

The public API must remain identical across platforms. Platform selection should
use Nim defines matching the existing clckr consumer conventions: `-d:ds3` for
3DS and `-d:vita` for Vita.

3DS backend work has a prerequisite: port SoLoud thread and mutex primitives to
libctru in the fork, because devkitARM does not provide pthreads. A real 3DS
backend should create its own C++/libctru audio thread, feed NDSP buffers, and
never enter the Nim runtime from that audio thread. The documented fallback is
NULLDRIVER plus an explicit mixer pump, but that is single-threaded and should
be treated as fallback only.

For 3DS hardware docs, mention the `dspfirm.cdc` prerequisite. Agents can
cross-compile artifacts, but real 3DS and Vita hardware verification remains a
human gate.

## Runtime Safety And Memory Constraints

Phase-1 code must respect real-time audio constraints even though advanced
middleware systems are out of scope.

- No Nim runtime interaction from platform audio callbacks or platform audio
  threads.
- No heap allocation, disk IO, or blocking operations on the audio render path.
- Keep shutdown deterministic: stop voices, release assets, deinitialize the
  SoLoud engine, then destroy owned state.
- Use streaming for music and long tracks; do not load music fully resident by
  default.
- Enforce conservative voice limits suitable for 3DS memory constraints.
- Treat dead, invalid, and stolen handles as normal states that are cheap and
  safe to query.

## Testing Strategy

Tests use `bddy` from `~/git/bddy`, pinned like the other birbparty fork
dependencies. Test code should use bddy's BDD style (`given`, `act`, `then`,
`verify`) and support normal `nim c -r` execution.

Phase-1 test coverage should include:

- Raw binding compile and smoke tests using NULLDRIVER or NOSOUND.
- Safe wrapper lifecycle, init failure, asset loading, invalid asset, handle,
  bus, fade, voice-limit, and shutdown-order tests.
- Public API tests that import only `play`.
- Stress tests for repeated init/shutdown, rapid load/play/stop, and bounded
  voice exhaustion.
- Generated or CC0-compatible WAV/OGG fixtures, including a long OGG for
  streaming behavior.

CI should run a desktop matrix for Linux, macOS, and Windows, then cross-compile
the examples for 3DS and Vita without attempting hardware execution.

Final phase-1 acceptance also requires three example programs: a WAV SFX
keypress example, a looping streamed OGG music fade example, and a bus volume
demo. Agents can build and run these on desktop, cross-compile them for 3DS and
Vita, and document the remaining real-hardware checks as human gates.

## Packaging And Consumption

The standard layout is:

```text
play.nimble
nim.cfg
nim_3ds.cfg
nim_vita.cfg
config.nims
src/play.nim
src/play/
tests/
examples/
vendor/soloud/
scripts/
```

`nim.cfg` must include `--path:"src"` for local development and editor tooling.

`play` must work both as a URL-pinned nimble dependency and as a path-injected
library for console-style consumers that bypass nimble. Vendored SoLoud source
paths must therefore resolve relative to the library modules rather than the
consumer project.

## Future Seams, Not Phase-1 Work

The clean-room docs describe the intended direction after phase 1:

- Data-driven events, parameters, states, switches, and containers.
- Adaptive music segments, transitions, beat/bar scheduling, and layered stems.
- Richer bus routing, submixes, metering, mute/solo, and DSP insertion.
- Spatial audio, occlusion, voice prioritization, and virtual voices.
- Bank building, hot reload, profiling, live debugging, plugin SDK, and visual
  authoring tools.
- Nim macros for typed event, parameter, state, and switch identifiers.

Agents should preserve seams for those features by keeping handles opaque,
keeping assets and playback separate, centralizing routing through buses,
avoiding raw SoLoud exposure in public APIs, and documenting thread boundaries.
Do not implement future middleware systems in phase 1 unless a later bead
explicitly changes the scope.
