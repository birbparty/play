# Project Planning with Beads

## Agent Instructions

You are an expert software architect creating a comprehensive task breakdown. This task graph will be executed by AI agents working in parallel, coordinated through MCP Agent Mail with file reservations to prevent conflicts.

<quality_expectations>
Create a thorough, production-ready task graph. Include all necessary setup, implementation, testing, and documentation tasks. Go beyond the basics - consider edge cases, error handling, security considerations, and integration points. Each task should be specific enough for an agent to execute independently without ambiguity.
</quality_expectations>

## Project Information

### Links to Relevant Documentation

**Local design docs (read these first):**
- `docs/soloud.md` — SoLoud adoption rationale, 3-layer binding architecture, 3DS/Vita backend designs, phase priorities
- `docs/clean-room1.md` — Nim audio middleware architecture: handle-based APIs, mixer/DSP graph, threading model, memory rules
- `docs/clean-room2.md` — Middleware vision: events, parameters, states, switches, containers, adaptive music, profiler (future roadmap context)
- `docs/clean-room3.md` — Runtime architecture: command queue, core objects, backend abstraction, milestone roadmap

**Consumer project (first user of this library):**
- `~/git/birbparty/clckr` — Nim 2.0 idle clicker targeting desktop GL, Nintendo 3DS (`-d:ds3`, devkitARM), and PS Vita (`-d:vita`, VitaSDK). See `clckr.nimble` for the URL-pinned fork dependency pattern, `config.nims`, `nim_3ds.cfg`, `nim_vita.cfg`, and `scripts/` for per-platform build conventions. Built with `nim c`, NOT `nimble build`.

**Testing framework (required):**
- `~/git/bddy` — Spock-inspired BDD testing framework for Nim (`given/act/then`, `verify:`, `where:` data tables, lifecycle hooks, power asserts, Console/TAP/JUnit formatters). Nim 2.0+, MIT. See its README and `examples/` for usage patterns.

**SoLoud:**
- **birbparty fork (source of truth for this project):** https://github.com/birbparty/soloud, local checkout at `~/git/soloud`. The 3DS backend is developed here; vendored sources in this repo are snapshots of this fork at a pinned SHA.
- Upstream repo: https://github.com/jarikomppa/soloud (zlib license)
- Official docs: http://soloud-audio.com
- C API header: https://github.com/jarikomppa/soloud/blob/master/include/soloud_c.h
- C API usage demo: https://github.com/jarikomppa/soloud/blob/master/demos/c_test/main.c
- miniaudio backend: https://github.com/jarikomppa/soloud/blob/master/src/backend/miniaudio/soloud_miniaudio.cpp

**Nintendo 3DS (homebrew):**
- libctru repo: https://github.com/devkitPro/libctru
- libctru docs: https://devkitpro.github.io/libctru/
- NDSP API reference: https://libctru.devkitpro.org/ndsp_8h.html

**PS Vita (homebrew):**
- VitaSDK: https://vitasdk.org/
- audioout.h reference: https://docs.vitasdk.org/audioout_8h.html
- Audio module docs: https://docs.vitasdk.org/group__Audio.html

**Nim FFI / binding tooling:**
- Futhark (clang-based automatic C header wrapping): https://github.com/PMunch/futhark
- Status Nim style guide, C interop section: https://status-im.github.io/nim-style-guide/interop.c.html
- Prior art (stale, Nim 0.16-era, c2nim-generated — reference only, not a dependency): https://github.com/zacharycarter/soloud-nim

### Project Description

**`play`** — a Nim audio library for game development, built on SoLoud as the underlying audio engine. The library, nimble package, and top-level module are all named `play`; it lives in **this repo** (`github.com/birbparty/play`), following the birbparty naming style (boxy, inputty, shady, bddy). Phase-1 directory layout: standard nimble layout with `src/play.nim` (+ `src/play/` submodules), `tests/`, `examples/`, `vendor/soloud/`, a root `nim.cfg` with `--path:"src"`, and per-platform `nim_3ds.cfg` / `nim_vita.cfg`.

Provides a three-layer architecture: raw Nim bindings over SoLoud's C API, a safe Nim wrapper, and a Nim-first game-facing API (load/play sounds, streaming music, handles, buses, volume control, fades). Target platforms: desktop (Windows/Linux/macOS), Nintendo 3DS homebrew (devkitARM/libctru/NDSP), and PS Vita homebrew (VitaSDK/AudioOut). WebAssembly is **not** a target.

clckr (an idle clicker game at `~/git/birbparty/clckr`) will be the first consumer of the library, but **clckr-side integration work is out of scope for this task graph** — acceptance is via example programs in this repo (see Specific Requirements). The library must remain consumable by clckr's build flows as a design constraint.

This scope is **phase 1**. The longer-term vision (documented in `docs/clean-room1.md` through `docs/clean-room3.md`) includes advanced middleware features: event/parameter-driven adaptive audio, state-based music systems, audio banks and asset pipeline, runtime profiler, live debugging, plugin SDK, and visual authoring tools. Phase 1 architecture decisions should not preclude these — but do not build them now.

**Precedence note:** the Specific Requirements section below defines phase 1. The phase/milestone numbering inside the four design docs (`docs/soloud.md` Phases 1–5, clean-room milestone roadmaps) is superseded by this document; the clean-room docs are vision context only, and `docs/clean-room2.md`'s proposed repository layout (`runtime/`, `editor/`, etc.) is future vision, not the phase-1 layout.

### Technical Stack

- **Nim 2.0+** (ARC/ORC memory management; no GC interaction in the audio callback)
- **SoLoud** (C++ engine, zlib license), consumed from the **birbparty/soloud fork** (`~/git/soloud`, https://github.com/birbparty/soloud): vendored into this repo at `vendor/soloud/` as a snapshot of the fork at a pinned SHA, and compiled via Nim's `{.compile.}` facilities. All SoLoud patches (3DS backend, `soloud_thread` port, any Vita fixes) land in the fork first, then get re-vendored — never edit `vendor/soloud/` directly. Vendored source paths must resolve relative to the library's own source files (which `{.compile.}` supports), so the library works both as a nimble dependency and via `--path` injection.
- **Compilation model:** the library must work under Nim's **C backend** (`nim c` — clckr's flow), not require `nim cpp`. `soloud_c.cpp` is the `extern "C"` seam; the vendored C++ is compiled as C++ via `{.compile.}` while the Nim side stays on the C backend.
- **Bindings over SoLoud's C API** (`soloud_c.h`): resolve via a **p0 decision-spike bead** with these criteria — if Futhark output for `soloud_c.h` compiles clean on Nim 2.x and cross-compiles under devkitARM/VitaSDK, commit the generated output (consumers must never need libclang); otherwise hand-write the bindings. All downstream binding beads depend on this spike.
- **Desktop backends:** SoLoud's native backends (miniaudio preferred; SDL2/WASAPI/CoreAudio/ALSA as alternatives)
- **Console backends — decided integration model** (SoLoud's C API has no custom-backend registration; backends are compiled-in C++):
  - **PS Vita:** upstream SoLoud already ships a `vita_homebrew` backend (`src/backend/vita_homebrew/`, `SOLOUD_VITA_HOMEBREW` in the C-API enum; present in the fork). First Vita task is *evaluate and build the existing backend under VitaSDK*, not design a new one. Any fixes land in the birbparty/soloud fork.
  - **Nintendo 3DS — in-tree backend in the birbparty/soloud fork.** No upstream backend exists; write one inside the fork (`src/backend/ctru_ndsp/` or similar), **modeled on `vita_homebrew`**: ring buffer + a platform audio thread created in C++ (libctru thread) that runs only SoLoud's C++ mixer and feeds NDSP wave buffers. This is compatible with clckr's `--threads:off` console builds (verified in `nim_3ds.cfg`/`nim_vita.cfg`) because the audio thread never enters the Nim runtime. Required patch surface in the fork: backend directory, enum value in `soloud.h` mirrored in `soloud_c.h`, dispatch case in `soloud.cpp` `init()`. A real backend also creates SoLoud's internal audio mutex, making the public API thread-safe — which the fallback below lacks.
  - **Documented fallback only:** `SOLOUD_NULLDRIVER` init + a C-glue pump calling `Soloud_mixSigned16()` from the game loop. Use only if the in-tree backend proves unworkable; note NULLDRIVER creates no audio mutex, so the pump model is single-threaded by construction and couples audio cadence to frame rate.
  - **`soloud_thread` portability task (prerequisite for the 3DS backend):** SoLoud's core `soloud_thread.cpp` falls back to pthreads on non-Windows, and devkitARM has no pthreads — neither thread creation nor the mutexes behind the C API's internal locking will build. Port `soloud_thread` to libctru primitives in the fork; this is what gives the in-tree backend working thread/mutex support.
- **Cross-compilation toolchain config:** clckr's proven `nim_3ds.cfg`/`nim_vita.cfg` configure only the C compiler (`arm.linux.gcc.*` keys — verified). This library's per-platform cfgs additionally need the C++ compiler keys (`arm-none-eabi-g++`, `arm-vita-eabi-g++`), `-lstdc++` on the 3DS link line (Vita already links it for vitaGL), and likely `-fno-exceptions -fno-rtti` given `--opt:size` on 3DS.
- **Testing:** bddy (`~/git/bddy`) as the test framework
- **Packaging:** Nimble package; build patterns mirroring clckr's `nim c` + per-platform cfg approach (`nim_3ds.cfg`, `nim_vita.cfg`, `config.nims`)
- A root `nim.cfg` with `--path:"src"` (required for editor LSP to resolve imports)

### Specific Requirements

- **Licensing:** zlib/permissive throughout (including test fixtures and example assets); commercial-friendly; no proprietary SDK redistribution (homebrew toolchains only: devkitARM/libctru, VitaSDK).
- **API design:** three-layer architecture (raw bindings → safe wrapper → game-facing `play` API); game code never touches SoLoud directly; handle-based, no exposed pointers.
- **Phase-1 public API surface** (the minimum; one bead per API group, do not invent beyond this):
  - Lifecycle: `init()`, `shutdown()` (clean shutdown ordering).
  - Assets: `loadSound(path)` (resident, for SFX), `loadMusic(path)` (streamed, for music). WAV + OGG for both.
  - Playback: `play(sound) → Handle`, `playMusic(music) → Handle`.
  - Handle ops: `pause`, `resume`, `stop`, `setLooping`, per-handle `setVolume`, validity check on a dead/stolen handle is safe and cheap.
  - Buses: a **fixed** set — `music`, `sfx`, `ui` — routed to master, with per-bus volume (`setMusicVolume`, `setSfxVolume`, `setUiVolume`) plus `setMasterVolume`. Sounds route to a bus at `play` time (default `sfx`; music to `music`). No public bus-creation API, no mute/solo/metering in phase 1.
  - Fades: per-handle volume fade (`fadeVolume(handle, target, seconds)`) plus convenience `fadeInMusic`/`fadeOutMusic`. `stop`-after-fade scheduling included.
- **Real-time safety:** no allocations or GC interaction in the audio callback; thread-safe public API; clean shutdown ordering.
- **Memory constraints:** must run on 3DS (~64–128MB usable) and Vita (~512MB) — streaming for music, voice limits, asset unloading.
- **Platform parity:** identical public API across Windows/Linux/macOS/3DS/Vita; platform selection via `define` flags matching clckr's conventions (`-d:ds3`, `-d:vita`). WASM is out of scope.
- **Consumption modes (clckr design constraint, no clckr beads in this graph):** the library must be consumable BOTH (a) as a URL-pinned nimble dependency the way clckr pins boxy/inputty/shady (desktop flow), AND (b) via `--path` injection by build scripts, the way clckr's `build_3ds.sh`/`build_vita.sh` inject shady — clckr's console builds bypass nimble entirely (verified: ds3/vita builds copy per-platform cfgs over `nim.cfg` and run bare `nim c`). Vendored SoLoud sources must resolve correctly under both modes.
- **3DS specifics:** NDSP's native output rate is ~32728 Hz but `ndspChnSetRate` resamples per channel — run SoLoud at 44100 Hz feeding one stereo channel (confirm in the backend spike). On-device audio requires the user-dumped DSP firmware blob (`dspfirm.cdc`); without it NDSP fails on hardware while working in Citra — the hardware-verification gate must state this prerequisite.
- **Hardware verification is human-in-the-loop:** agents cannot flash a 3DS or Vita. Console hardware-verification beads are explicit human gates: the agent produces the artifact (`.3dsx` example / `.vpk` example) and build instructions; the user runs it on hardware and reports back. The agent-verifiable proxy before the gate is: clean cross-compile of the examples for both consoles + full null-backend test suite passing on host.
- **Acceptance criteria (phase 1 done):** example programs in `examples/` — (1) play a WAV SFX on keypress, (2) play looping streamed OGG music with fade-in/fade-out, (3) bus volume demo — run correctly on desktop (verified by running them), and the same examples cross-compile to `.3dsx`/`.vpk` and pass the human hardware gate on real 3DS and Vita.
- **Testing:** all tests written with bddy (`~/git/bddy`), pinned as a nimble dependency using the same URL-pin pattern clckr uses for its forks. Unit tests for the wrapper layer; host-runnable mixer tests using `SOLOUD_NULLDRIVER`/`SOLOUD_NOSOUND` (both exist in the C API) so the suite runs headless in CI.
- **Test fixtures:** committed under `tests/fixtures/` — short WAVs generated programmatically (sine-wave writer checked in as a tool or pre-generated), plus a short OGG and a long (≥60s) OGG for streaming tests, either generated or CC0-sourced; all fixture licensing zlib/CC0-compatible and documented.
- **CI:** GitHub Actions. Desktop matrix (Linux/macOS/Windows) running build + full bddy suite; cross-compile-only jobs for 3DS and Vita using the `devkitpro/devkitarm` and `vitasdk/vitasdk` docker images (build the examples, no execution).
- **Future-proofing (design-only, no implementation):** keep seams for the phase-2+ middleware features (events/parameters, adaptive music, profiler, plugins, visual editor) described in the clean-room docs.

---

## Your Task

Analyze this project and create a comprehensive **Beads task graph** using the `bd` CLI. Beads provides dependency-aware, conflict-free task management for multi-agent execution.

---

<critical_constraint>
Your ONLY output is a bash shell script. Do NOT use `bd add` — the correct command to create a bead is `bd create`. Use `bd dep add` for dependencies. Do not implement anything yourself.
</critical_constraint>

## Output Format

Generate a shell script that creates the full task graph. The script should:

1. **Initialize Beads** (if not already initialized)
2. **Create all beads** with appropriate priorities
3. **Establish dependencies** between beads
4. **Add labels** for phase grouping

### Example Output

```bash
#!/bin/bash
# Project: play
# Generated: 2026-06-10

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating project beads..."

# ========================================
# Phase 1: Project Setup & Infrastructure
# ========================================

SETUP_VITE=$(bd create "Initialize project with Vite + React + TypeScript" -p 0 --label setup --silent)

SETUP_LINT=$(bd create "Configure ESLint, Prettier, and TypeScript strict mode" -p 1 --label setup --silent)
bd dep add $SETUP_LINT $SETUP_VITE

SETUP_TAILWIND=$(bd create "Set up Tailwind CSS with design system tokens" -p 1 --label setup --silent)
bd dep add $SETUP_TAILWIND $SETUP_VITE

SETUP_TESTING=$(bd create "Configure testing framework (Vitest + Testing Library)" -p 1 --label setup --silent)
bd dep add $SETUP_TESTING $SETUP_LINT

# ========================================
# Phase 2: Core Architecture
# ========================================

API_CLIENT=$(bd create "Implement API client with error handling and retries" -p 0 --label core --silent)
bd dep add $API_CLIENT $SETUP_VITE

STATE_MGMT=$(bd create "Set up global state management (Zustand/Jotai)" -p 0 --label core --silent)
bd dep add $STATE_MGMT $SETUP_VITE

AUTH_CONTEXT=$(bd create "Create authentication context and hooks" -p 0 --label core --silent)
bd dep add $AUTH_CONTEXT $STATE_MGMT
bd dep add $AUTH_CONTEXT $API_CLIENT

# ... continue for all phases ...

echo ""
echo "Bead graph created! View with:"
echo "  bd ready              # List unblocked tasks"
```

---

## Bead Creation Guidelines

### Priority Levels
- `-p 0` = Critical (blocking other work)
- `-p 1` = High (important but not blocking)
- `-p 2` = Medium (standard work)
- `-p 3` = Low (nice to have)

### Labels (Phase Grouping)
Use `--label` to group beads by phase:
- `setup` - Project initialization
- `core` - Core architecture
- `auth` - Authentication/authorization
- `ui` - UI components
- `feature-{name}` - Feature-specific work
- `testing` - Test coverage
- `docs` - Documentation
- `deploy` - Deployment/CI

### Dependency Rules
1. Never create cycles
2. Every bead should have a clear dependency chain back to setup tasks
3. Use `bd dep add CHILD PARENT` (child depends on parent completing first)
4. Parallel work should share a common ancestor, not depend on each other

### Task Granularity
- Each bead should be completable in **under 750 lines of code**
- Tasks should be atomic enough for one agent to complete without coordination
- If a task requires multiple file areas, consider splitting by file area

---

## File Reservation Planning

For each major work area, note the file patterns that will need exclusive reservation:

```bash
# Example reservation notes (add as bead descriptions)
# Auth work: src/auth/**, tests/auth/**, src/hooks/useAuth*
# API client: src/api/**, src/lib/fetch*, tests/api/**
# UI components: src/components/{ComponentName}/**, tests/components/{ComponentName}/**
```

This helps agents claim appropriate file surfaces when they start work.

---

## Context Documentation

Place any important context in `prompts/docs/` for agents to reference. This includes:
- Architecture decisions
- API documentation
- Design system specs
- External service integration guides

---

## Verification Steps

After generating the script:

1. **Run it**: `chmod +x setup-beads.sh && ./setup-beads.sh`
2. **Check ready work**: `bd ready` should show initial setup tasks

---

## Completeness Checklist

Ensure your task graph includes:

- [ ] All setup and configuration tasks
- [ ] Core architecture and shared utilities
- [ ] Feature implementation tasks (broken into small units)
- [ ] Error handling and edge cases
- [ ] Unit and integration tests for each feature
- [ ] API documentation
- [ ] Security considerations (input validation, auth checks)
- [ ] Performance considerations where relevant
- [ ] CI/CD and deployment tasks
- [ ] Clear dependency chains with no cycles
