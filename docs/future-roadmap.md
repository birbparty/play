# Future Middleware Roadmap

This document connects the current phase-1 `play` API to the longer clean-room
middleware direction. It is descriptive, not a commitment that the listed
systems exist today.

Phase 1 remains a file-and-handle playback library:

- lifecycle and backend selection
- resident `Sound` and streamed `Music` assets
- `Handle` playback controls
- fixed `music`, `sfx`, and `ui` buses
- fades and stop-after-fade helpers
- desktop, 3DS, and Vita build verification

Everything below is future scope unless a later phase explicitly implements it.

## Phase 2: Richer Mixing Surface

Phase-1 buses prove the public API can expose mixer controls without exposing
native engine handles. The next mixer step can add custom buses, submixes,
metering, mute/solo, voice priority, voice stealing policy, and basic DSP
inserts.

Reserved seams:

- fixed buses become the compatibility baseline for custom routing
- opaque handles remain the public reference for active voices
- backend and raw SoLoud details stay behind wrapper modules

Still out of scope until implemented: graph editing, bus creation, meters,
effect insertion, public voice-priority APIs, and spatial audio controls.

## Phase 3: Events, Parameters, And States

Phase 3 is the first move from "play this file" to "trigger this authored
behavior." The phase-1 asset boundary keeps that migration possible because
events can resolve internally to resident sounds, streamed music, buses, and
handles.

Expected future systems:

- authored event metadata
- runtime parameters such as speed, health, threat, or surface type
- states and switches for global or contextual mix changes
- random containers, avoid-repeat behavior, and pitch/volume variation
- generated typed identifiers for Nim callers

Out of scope today: `trigger`, `setParameter`, `setState`, event banks,
parameter curves, switch containers, and generated authoring metadata.

## Phase 4: Adaptive Music

Phase-1 `Music` assets and fade helpers reserve a small music-specific surface.
Future adaptive music should build from streamed assets toward authored music
graphs.

Expected future systems:

- intro, loop, transition, and outro segments
- layered stems
- state-driven music changes
- crossfades and scheduled transitions
- mixer-clock scheduling for musical timing

Out of scope today: beat/bar quantization, stem toggles, segment metadata,
transition rules, and sample-accurate music graph scheduling.

## Phase 5: Banks And Asset Pipeline

The current loader accepts files directly. A future bank pipeline can package
audio files plus the event/parameter/routing schema into platform-aware
artifacts.

Expected future systems:

- bank build tooling
- streaming-aware packaging for console memory budgets
- codec and metadata manifests
- hot reload for development
- reproducible cooked assets for CI

Out of scope today: bank files, cooking tools, bank mounts, dependency
tracking, hot reload, and replacing direct file loading.

## Phase 6: Plugins, Profiler, And Live Debugging

Phase 1 intentionally compiles a known source closure. Later phases can open
controlled extension points once the runtime data model is stable.

Expected future systems:

- codec plugins
- DSP plugins
- spatializer plugins
- voice, CPU, memory, streaming, and bus-level profiler data
- remote inspection of active voices, buses, events, and parameters
- live mix adjustment during development

Out of scope today: plugin ABI, dynamic loading, plugin registration, profiler
transport, remote control, and live-edit protocols.

## Phase 7: Visual Authoring Tools

Visual tooling should come after the runtime schema exists. The editor should
author the same events, parameters, states, routing, music graphs, and banks
that the runtime consumes.

Expected future systems:

- event and container editor
- parameter/state authoring
- mixer and snapshot authoring
- adaptive music graph editor
- bank build integration
- generated Nim identifiers from authored metadata

Out of scope today: editor UI, editor project files, visual previews, metadata
round trips, and tool-generated code.

## Compatibility Rules For Future Phases

- Keep `import play` as the game-facing entry point.
- Keep public resources opaque; do not expose raw SoLoud pointers or voice ids.
- Preserve phase-1 direct file playback for small projects and tests.
- Keep platform audio callbacks in C/C++ backend code, not Nim callbacks.
- Treat docs, examples, and CI cross-compiles as part of every phase.
- Mark unimplemented middleware systems clearly until they have tests and
  examples.

The detailed phase roadmap remains in `docs/ROADMAP.md`. The current
real-time boundary is documented in `docs/realtime-safety.md`.
