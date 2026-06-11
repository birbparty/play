# play — Roadmap

`play` is a Nim audio library for game development, built on SoLoud
(zlib-licensed C++ engine), vendored from the
[birbparty/soloud fork](https://github.com/birbparty/soloud) where all SoLoud
patches (3DS backend, thread port) are developed. It lives at
`github.com/birbparty/play` and follows the birbparty ecosystem conventions
(boxy, inputty, shady, bddy). First consumer:
[clckr](https://github.com/birbparty/clckr).

Phase 1 is specified in detail in
`docs/prompts/nim-audio-library-for-game-development-built-on-soloud.md`.
Phases 2+ distill `docs/soloud.md`'s feature phases and the long-term vision
in `docs/clean-room1.md` – `docs/clean-room3.md`; their scope is directional,
not committed.

`docs/architecture.md` describes the phase-1 architecture and the seams it
preserves for later middleware systems. `docs/future-roadmap.md` maps those
seams to the future clean-room roadmap while marking unimplemented systems as
out of current scope.

---

## Phase 1 — Core playback (committed)

The SoLoud foundation and a Nim-first game-facing API.

- SoLoud vendored from the birbparty/soloud fork (pinned SHA), compiled via
  `{.compile.}`; bindings over `soloud_c.h` (Futhark-vs-hand-written decided
  by a p0 spike)
- Three layers: raw bindings → safe wrapper → `play` public API
- WAV + OGG; resident sounds (`loadSound`) and streamed music (`loadMusic`)
- Handles: pause/resume/stop/loop, per-handle volume, cheap validity checks
- Fixed buses (`music`, `sfx`, `ui` → master) with per-bus + master volume
- Fades: per-handle fade, `fadeInMusic`/`fadeOutMusic`, stop-after-fade
- Platforms: Windows, Linux, macOS (miniaudio preferred), Nintendo 3DS
  (in-tree NDSP backend written in the birbparty/soloud fork, modeled on
  `vita_homebrew` — prerequisite: port `soloud_thread` to libctru primitives
  in the fork; NULLDRIVER + pump as documented fallback), PS Vita
  (evaluate upstream `vita_homebrew` backend first)
- bddy test suite (null-backend, headless), CI with desktop matrix +
  devkitARM/VitaSDK cross-compile jobs
- Acceptance: three example programs running on desktop and passing
  human hardware gates on real 3DS and Vita

Out of scope for phase 1: WASM, clckr-side integration (separate follow-up
work in the clckr repo once phase 1 ships).

## Phase 1.5 — clckr integration (committed, separate work)

- Pin `play` in clckr by SHA (desktop) and inject via `--path` in
  `build_3ds.sh`/`build_vita.sh` (consoles)
- Click SFX + looping background music in clckr on all three platforms
- Feedback from real-game use drives the phase 2 priority order

## Phase 2 — Richer mixing & spatial basics

- Public bus creation/routing API (beyond the fixed phase-1 set), submixes
- Mute/solo and basic bus metering
- More DSP: low/high-pass filters, echo/reverb inserts (SoLoud built-ins
  exposed through the wrapper)
- More codecs, near-free wins: MP3 and FLAC (the vendored SoLoud already
  decodes both)
- Procedural sources: expose SoLoud's sfxr and speech-synthesis built-ins
  (sfxr blips are a natural fit for clckr)
- Basic spatial audio: listener, emitter position, distance attenuation,
  stereo panning, doppler (SoLoud 3D API); optional simple occlusion
  (obstruction value → volume/LPF)
- Voice prioritization and voice-stealing controls, virtual voices
- Keep the spatializer behind a seam the phase-6 plugin SDK can later expose
- Ordering is clckr-driven: an idle clicker needs phase 3's variation system
  more than spatial audio — the spatial bullets can slide past phase 3 (or
  variation pull forward) based on phase-1.5 feedback

## Phase 3 — Data-driven events & parameters

The first step away from "file player" toward middleware
(clean-room2's core idea: game code triggers events, never files).

- **Define the authored-data schema first** (events, parameters, containers,
  routing): this same schema is the bank metadata that phase 5 packages —
  one format, no phase-5 migration
- Event system: `play.trigger("weapon.fire")` — events defined in data,
  mapping to sounds, routing, randomization
- Runtime parameters (`speed`, `threat`…) driving volume/pitch/filter
  via curves
- Variation: random containers (weighted, avoid-repeat), pitch/volume
  randomization
- States and switches (surface type → footstep variant)
- Mix snapshots: state-driven bus volume/effect presets (states drive
  snapshots — the runtime capability phase 7's editor authors)
- Compile-time Nim niceties: generate typed event/parameter identifiers
  from authored metadata via macros

## Phase 4 — Adaptive music

- Music segments (intro/loop/outro) and state-based music
  (exploration/combat/boss) with crossfade and beat/bar-quantized
  transitions
- Layered stems with independent enable/disable
- Sample-accurate scheduling on the mixer clock

## Phase 5 — Asset pipeline & banks

- Audio banks: bundled assets + the phase-3 metadata schema (events,
  parameters, routing) — packaging, not a new format
- Build tooling to compile authored data into banks; streaming-aware
  packaging for 3DS/Vita memory budgets
- Bank format treats codecs as pluggable (the seam phase 6's codec
  plugins slot into); codec expansion lands here or as plugins: Opus,
  tracker formats (MOD/XM/IT via OpenMPT)
- Hot reload of banks during development

## Phase 6 — Plugin SDK, profiling & live debugging

- Plugin SDK (DSP effects, codecs, spatializers) — pulled ahead of tooling
  because codec plugins constrain phase 5's bank format and spatializer
  plugins constrain phase 2's spatial seam
- Runtime profiler: voice count, CPU, memory, streaming and bus levels
- Live remote inspection: connect to a running game, watch voices/buses,
  trigger events, adjust the mix

## Phase 7 — Visual authoring tools

- Editor for events, containers, music graphs, and mix snapshots — the
  clean-room2 "authoring independence" goal, where sound designers work
  without engine code changes
- Bank generation from the editor; round-trips the phase-3 schema

## Cross-cutting (standing concerns, every phase)

- **Fork hygiene:** birbparty/soloud tracks upstream jarikomppa/soloud;
  sync upstream into the fork on need (codec/bug fixes), not on cadence,
  then re-vendor into `play` at a new pinned SHA
- **Releases:** tagged semver + changelog starting when phase 1 ships;
  clckr pins by SHA/tag. Phase 3 changes the programming model
  (file-player → events), so it lands as a major version
- **Docs:** API docs (`nim doc`), getting-started, and console porting
  notes are a standing deliverable of each phase, not a separate phase

## Platform expansion (opportunistic, post-phase-1)

- WebAssembly (Emscripten; SDL-static or miniaudio/AudioWorklet)
- Nintendo Switch homebrew, Android, iOS, Steam Deck, Dreamcast
