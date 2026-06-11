# play Architecture

`play` phase 1 is a Nim-first wrapper over the vendored SoLoud engine. Its
current job is intentionally small: lifecycle, asset loading, playback handles,
fixed buses, fades, platform backend selection, examples, and verification. It
does not include an event system, runtime parameters, adaptive music, profiling,
plugins, or visual authoring tools.

This document describes the phase-1 architecture and the seams it preserves for
future clean-room middleware work. The seams are reservations, not implemented
systems.

## Layers

```text
game code
  -> import play
  -> public modules: lifecycle/assets/playback/handles/buses/fades/types
  -> private wrapper modules and global engine ownership
  -> handwritten Nim imports over SoLoud's generated C API
  -> vendored SoLoud C/C++ sources and platform backends
```

Game code should import only the top-level `play` facade. Raw bindings,
`play/soloud`, and `play/private/*` are implementation details.

The public layer exposes opaque Nim types and result objects. It hides native
pointers, SoLoud voice ids, bus handles, and backend-specific details. That is
the main architectural constraint future systems should preserve.

## Phase-1 Core

### Lifecycle

`init`, `shutdown`, and `withPlay` own a single global engine instance. Backend
selection is explicit through `initOptions` but defaults to the target platform:
desktop auto backend, 3DS NDSP, or Vita homebrew. Host tests use `NULLDRIVER`
and `NOSOUND` for deterministic CI.

Future systems that need regular updates, command queues, bank reloads, or
remote inspection should attach to lifecycle ownership instead of creating
separate global audio engines.

### Assets

`loadSound` represents resident sound effects and `loadMusic` represents
streamed music. Both return opaque public assets with explicit disposal. The
loader boundary is the future place for bank lookup, codec selection, streaming
budgets, and hot reload.

Phase 1 deliberately accepts file paths. It does not provide authored events,
asset banks, dependency graphs, or content cooking.

### Playback Handles

`play` and `playMusic` return cheap opaque `Handle` values. Public operations
validate handles against the current engine and return `PlayResult` instead of
exposing raw voice ids. Handles may become invalid after stop, voice stealing,
or shutdown.

This handle model is the future bridge to event instances, profiler rows,
voice-priority decisions, and tooling selection. Future APIs should keep the
same rule: callers hold stable public identifiers, not engine pointers.

### Fixed Buses

Phase 1 exposes `musicBus`, `sfxBus`, and `uiBus`, routed to the master bus
inside the wrapper. Public controls set master and fixed-bus volume only.

This establishes a routing seam without committing to a user-defined mixer
graph. Future custom buses, snapshots, meters, and visual mixer tools should
extend this boundary rather than replacing fixed-bus behavior that phase-1
users depend on.

### Fades

Fades are scheduled through SoLoud handle operations. `fadeInMusic` and
`fadeOutMusic` provide the first time-based behavior in the public API, while
keeping scheduling inside the audio engine.

Future adaptive music and state transitions can build on this idea, but phase 1
does not expose beat grids, segment timelines, stem control, or sample-accurate
music scheduling.

## Future Middleware Seams

### Events

The clean-room roadmap expects game code to eventually trigger authored events
instead of file paths. Phase 1 leaves room for this by keeping assets and
handles opaque:

- an event can resolve to one or more `Sound` or `Music` assets internally
- event playback can still return public handles or event-instance ids
- routing and randomization can remain hidden behind result-returning calls

Out of scope today: `trigger`, event metadata, random containers, authored
routing rules, and generated event identifiers.

### Parameters And States

Runtime parameters and states will need a command boundary that can update
audio behavior without running arbitrary Nim code on the audio thread. Phase 1
keeps the public API synchronous and game-thread oriented, and the real-time
safety audit keeps Nim callbacks out of backend mixer callbacks.

Out of scope today: parameter ids, state ids, switches, curves, snapshots, and
parameter-driven pitch, volume, filter, or routing changes.

### Adaptive Music

The current split between resident sounds and streamed music is enough for
simple game music and for future music-system ownership. `Music` is already an
opaque asset and music playback already has dedicated helpers and bus routing.

Out of scope today: segments, markers, bars/beats, stem layers, transition
rules, quantized scheduling, and music-state graphs.

### Profiler And Live Tools

Handles, buses, lifecycle state, and typed errors are stable places to attach
observability later. Future profiler data can report active voices, bus levels,
streaming state, errors, backend selection, and asset ownership without
exposing raw SoLoud objects to game code.

Out of scope today: runtime profiler transport, remote inspection, live mix
editing, CPU/memory/voice counters, and tooling protocols.

### Plugins

The current implementation compiles a fixed SoLoud source closure and selects
platform backends at build time. That keeps phase-1 builds predictable for
desktop, 3DS, and Vita.

Future plugins should be designed as explicit extension points for codecs, DSP,
spatializers, importers, and tooling integrations. They should not require game
code to import raw binding modules or depend on the vendored SoLoud layout.

Out of scope today: dynamic plugin loading, plugin ABI, third-party DSP nodes,
codec registration, and spatializer registration.

### Visual Authoring

Visual tools need a data model first: events, parameters, states, routing,
music graphs, and banks. Phase 1 avoids inventing editor-facing formats before
those runtime concepts exist.

Out of scope today: editor UI, project files, bank authoring, preview playback
from tools, live authoring sessions, and generated code from authored metadata.

## Real-Time Boundary

Nim wrapper code runs on the application side. Platform audio callbacks remain
in C/C++ backend code and call SoLoud mixer functions directly. Future systems
must preserve that boundary: authored behavior, parameters, live tools, and
plugins should communicate through queued data or engine-owned state, not Nim
callbacks invoked from platform audio threads.

See `docs/realtime-safety.md` for the current audit.
