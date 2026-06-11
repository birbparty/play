#!/usr/bin/env bash
# Project: play
# Generated: 2026-06-10
# Scope: Nim audio library for game development built on SoLoud

set -euo pipefail

if ! bd status >/dev/null 2>&1; then
  bd init --non-interactive --prefix play
fi

echo "Creating play task graph..."

# ========================================
# Phase 0: Planning, Scope, and Repo Setup
# ========================================

CONTEXT_DOCS=$(bd create "Create phase-1 agent context docs for play architecture" \
  -p 0 \
  --type task \
  --labels setup,docs \
  --description "Summarize docs/soloud.md and docs/clean-room*.md into prompts/docs/ or docs/agent-context.md, explicitly marking phase-1 scope versus future middleware roadmap. File reservations: docs/agent-context.md, prompts/docs/**." \
  --acceptance "Context doc states the three-layer architecture, SoLoud fork policy, platform targets, public API scope, test strategy, and future seams without assigning future features to phase 1." \
  --silent)

SETUP_LAYOUT=$(bd create "Initialize standard Nim package layout for play" \
  -p 0 \
  --type task \
  --labels setup \
  --description "Create standard nimble layout for the play package. File reservations: play.nimble, nim.cfg, src/play.nim, src/play/**, tests/**, examples/**, vendor/**, .gitignore." \
  --acceptance "Repo has src/play.nim, src/play/ submodules, tests/, examples/, vendor/soloud/ placeholder or snapshot location, root nim.cfg with --path:\"src\", and no implementation outside phase-1 boundaries." \
  --silent)
bd dep add "$SETUP_LAYOUT" "$CONTEXT_DOCS"

SETUP_NIMBLE=$(bd create "Configure play.nimble with URL-pinned dependencies" \
  -p 0 \
  --type task \
  --labels setup,packaging \
  --description "Define package metadata and dependency pins using clckr-style URL pins, including bddy from ~/git/bddy or its GitHub URL. File reservations: play.nimble." \
  --acceptance "play.nimble requires Nim >= 2.0.0, declares package name play, zlib/permissive license, pins bddy, and exposes test tasks that run bddy test binaries with nim c -r." \
  --silent)
bd dep add "$SETUP_NIMBLE" "$SETUP_LAYOUT"

TEST_BDDY_SETUP=$(bd create "Set up bddy test harness and conventions" \
  -p 0 \
  --type task \
  --labels testing,setup \
  --description "Add bddy imports, common test helpers, formatter options, and nimble test tasks before implementation beads start adding tests. File reservations: tests/common/**, tests/test_all.nim, play.nimble." \
  --acceptance "Tests use bddy spec/it/given/act/then/verify style, can run individually with nim c -r, and can emit JUnit/TAP for CI." \
  --silent)
bd dep add "$TEST_BDDY_SETUP" "$SETUP_NIMBLE"

SETUP_CONFIG=$(bd create "Add desktop and console Nim compiler configs" \
  -p 0 \
  --type task \
  --labels setup,platforms \
  --description "Create root nim.cfg plus nim_3ds.cfg and nim_vita.cfg matching clckr conventions, adding C++ compiler/linker settings required for SoLoud. File reservations: nim.cfg, nim_3ds.cfg, nim_vita.cfg, config.nims, scripts/**." \
  --acceptance "Configs support nim c on desktop, -d:ds3 with devkitARM/libctru, and -d:vita with VitaSDK; console cfgs include g++ toolchain keys, C++ runtime link flags, --threads:off, ARC/ORC-compatible memory flags, and repo-root-relative paths." \
  --silent)
bd dep add "$SETUP_CONFIG" "$SETUP_LAYOUT"

SETUP_SCRIPTS=$(bd create "Add build scripts for host, 3DS, and Vita examples" \
  -p 1 \
  --type task \
  --labels setup,platforms \
  --description "Create scripts that mirror clckr build flows and avoid nimble for console builds. File reservations: scripts/build_desktop_examples.sh, scripts/build_3ds_examples.sh, scripts/build_vita_examples.sh, scripts/common.sh." \
  --acceptance "Scripts build example programs with nim c, copy per-platform cfgs when needed, restore nim.cfg safely, create required empty stubs, and fail with clear prerequisite messages." \
  --silent)
bd dep add "$SETUP_SCRIPTS" "$SETUP_CONFIG"

LICENSE_REVIEW=$(bd create "Document licensing and third-party asset policy" \
  -p 1 \
  --type task \
  --labels setup,docs \
  --description "Document zlib/permissive license expectations for code, SoLoud, fixtures, generated assets, and homebrew toolchain constraints. File reservations: LICENSE, README.md, docs/licensing.md, tests/fixtures/README.md." \
  --acceptance "Docs state that SoLoud is zlib, proprietary SDK redistribution is out of scope, all fixtures are generated or CC0-compatible, and commercial use remains permitted." \
  --silent)
bd dep add "$LICENSE_REVIEW" "$CONTEXT_DOCS"

# ========================================
# Phase 1: SoLoud Fork and Vendoring
# ========================================

SOLOUD_AUDIT=$(bd create "Audit birbparty SoLoud fork for phase-1 integration points" \
  -p 0 \
  --type task \
  --labels soloud,setup \
  --description "Inspect ~/git/soloud at the intended pin for soloud_c.h, soloud_c.cpp, backend inventory, vita_homebrew backend, thread implementation, null/nosound backends, and source files needed for vendoring. File reservations: docs/soloud-vendor-audit.md." \
  --acceptance "Audit records the fork SHA, required files, backend enum values, C API availability, compile units, existing Vita backend status, and gaps for 3DS thread/backend support." \
  --silent)
bd dep add "$SOLOUD_AUDIT" "$CONTEXT_DOCS"

SOLOUD_VENDOR=$(bd create "Vendor pinned birbparty SoLoud snapshot" \
  -p 0 \
  --type task \
  --labels soloud,vendor \
  --description "Copy a snapshot from ~/git/soloud into vendor/soloud without editing vendored code directly. File reservations: vendor/soloud/**, docs/soloud-vendor.md." \
  --acceptance "vendor/soloud contains the pinned fork snapshot, includes the fork SHA in documentation, preserves license files, and documents that patches land in birbparty/soloud before re-vendoring." \
  --silent)
bd dep add "$SOLOUD_VENDOR" "$SOLOUD_AUDIT"

SOLOUD_COMPILE_MODEL=$(bd create "Implement Nim C-backend SoLoud C++ compile model" \
  -p 0 \
  --type task \
  --labels soloud,bindings \
  --description "Add Nim modules that compile vendored SoLoud C++ sources via {.compile.} while keeping Nim on the C backend. File reservations: src/play/soloud_compile.nim, src/play/private/soloud_sources.nim, vendor/soloud/**." \
  --acceptance "A minimal Nim program can compile SoLoud through nim c on host using soloud_c.cpp as the extern-C boundary, with source paths resolving relative to library modules." \
  --silent)
bd dep add "$SOLOUD_COMPILE_MODEL" "$SOLOUD_VENDOR"
bd dep add "$SOLOUD_COMPILE_MODEL" "$SETUP_CONFIG"

BINDING_SPIKE=$(bd create "Decide Futhark versus handwritten soloud_c.h bindings" \
  -p 0 \
  --type decision \
  --labels bindings,spike \
  --description "Run a p0 decision spike against soloud_c.h. File reservations: docs/bindings-decision.md, tools/bindings/**, src/play/bindings/**." \
  --acceptance "Decision doc records whether generated Futhark bindings compile cleanly on Nim 2.x and cross-compile for devkitARM/VitaSDK; if not, it specifies handwritten binding scope. Consumers must not need libclang." \
  --silent)
bd dep add "$BINDING_SPIKE" "$SOLOUD_COMPILE_MODEL"

RAW_BINDINGS=$(bd create "Implement raw Nim bindings for SoLoud C API" \
  -p 0 \
  --type task \
  --labels bindings,core \
  --description "Commit generated or handwritten raw bindings over soloud_c.h. File reservations: src/play/bindings/soloud_raw.nim, src/play/bindings/**, tests/bindings/**." \
  --acceptance "Raw bindings expose only the needed phase-1 C API symbols, compile under Nim 2.x with nim c, avoid C++ API exposure, and include compile smoke tests for host null/nosound backends." \
  --silent)
bd dep add "$RAW_BINDINGS" "$BINDING_SPIKE"

RAW_BACKEND_SELECT=$(bd create "Add backend selection constants and init mapping" \
  -p 0 \
  --type task \
  --labels bindings,platforms \
  --description "Map desktop default, NULLDRIVER, NOSOUND, VITA_HOMEBREW, and future CTRU_NDSP backend IDs through raw/safe layers. File reservations: src/play/backends.nim, src/play/bindings/soloud_raw.nim, tests/bindings/test_backends.nim." \
  --acceptance "Backend selection works through compile-time defines and runtime init options, with null/nosound available for headless tests and platform-specific IDs gated behind defines." \
  --silent)
bd dep add "$RAW_BACKEND_SELECT" "$RAW_BINDINGS"

# ========================================
# Phase 2: Safe Wrapper Layer
# ========================================

WRAP_LIFECYCLE=$(bd create "Implement safe SoLoud lifecycle wrapper" \
  -p 0 \
  --type task \
  --labels core,wrapper \
  --description "Wrap SoLoud engine creation, init, deinit, and destruction with deterministic shutdown ordering. File reservations: src/play/soloud.nim, src/play/private/lifecycle.nim, tests/wrapper/test_lifecycle.nim." \
  --acceptance "Wrapper supports init/shutdown idempotency rules, reports init errors without exposing raw pointers, and passes bddy tests using NULLDRIVER or NOSOUND." \
  --silent)
bd dep add "$WRAP_LIFECYCLE" "$RAW_BACKEND_SELECT"
bd dep add "$WRAP_LIFECYCLE" "$TEST_BDDY_SETUP"

WRAP_ERRORS=$(bd create "Define play error and result handling conventions" \
  -p 0 \
  --type task \
  --labels core,wrapper \
  --description "Create consistent errors for failed init, unsupported backend, load failures, invalid assets, and invalid handles. File reservations: src/play/errors.nim, src/play/soloud.nim, tests/wrapper/test_errors.nim." \
  --acceptance "Public and wrapper APIs return or raise documented Nim errors consistently, with tests for common failure paths and no leaked C resources after failures." \
  --silent)
bd dep add "$WRAP_ERRORS" "$WRAP_LIFECYCLE"
bd dep add "$WRAP_ERRORS" "$TEST_BDDY_SETUP"

WRAP_ASSETS=$(bd create "Implement safe sound and music asset wrappers" \
  -p 0 \
  --type task \
  --labels core,assets \
  --description "Wrap WAV and OGG loading for resident sounds and streamed music while hiding SoLoud handles. File reservations: src/play/assets.nim, src/play/soloud.nim, tests/wrapper/test_assets.nim, tests/fixtures/**." \
  --acceptance "loadSound-style resident wrappers and loadMusic-style streaming wrappers support WAV and OGG, expose deterministic unload/dispose semantics, clean up resources deterministically, reject missing/invalid files, and avoid loading music fully into memory." \
  --silent)
bd dep add "$WRAP_ASSETS" "$WRAP_ERRORS"
bd dep add "$WRAP_ASSETS" "$TEST_BDDY_SETUP"

WRAP_HANDLES=$(bd create "Implement safe voice handle wrapper operations" \
  -p 0 \
  --type task \
  --labels core,handles \
  --description "Provide handle validity, pause, resume, stop, looping, and per-handle volume wrappers. File reservations: src/play/handles.nim, src/play/soloud.nim, tests/wrapper/test_handles.nim." \
  --acceptance "Dead or stolen handles are cheap and safe to check; pause/resume/stop/setLooping/setVolume behave consistently under null/nosound tests." \
  --silent)
bd dep add "$WRAP_HANDLES" "$WRAP_ASSETS"
bd dep add "$WRAP_HANDLES" "$TEST_BDDY_SETUP"

CORE_VOICE_LIMITS=$(bd create "Implement voice-limit defaults and stealing policy" \
  -p 0 \
  --type task \
  --labels core,memory \
  --description "Define conservative default active-voice limits suitable for desktop, 3DS, and Vita, and expose internal configuration for SoLoud voice count/stealing behavior. File reservations: src/play/voices.nim, src/play/soloud.nim, tests/wrapper/test_voice_limits.nim." \
  --acceptance "Wrapper configures bounded active voices, documents default limits per platform, keeps invalid/stolen handle checks safe and cheap, and includes bddy tests for voice exhaustion or voice stealing behavior under null/nosound." \
  --silent)
bd dep add "$CORE_VOICE_LIMITS" "$WRAP_HANDLES"
bd dep add "$CORE_VOICE_LIMITS" "$TEST_BDDY_SETUP"

WRAP_BUSES=$(bd create "Implement fixed music, sfx, and ui bus routing" \
  -p 0 \
  --type task \
  --labels core,feature-buses \
  --description "Create fixed bus objects routed to master, with no public bus creation API. File reservations: src/play/buses.nim, src/play/soloud.nim, tests/wrapper/test_buses.nim." \
  --acceptance "music, sfx, and ui buses are initialized once, sounds route to a bus at play time with sfx default, music routes to music, and setMasterVolume/setMusicVolume/setSfxVolume/setUiVolume are tested." \
  --silent)
bd dep add "$WRAP_BUSES" "$WRAP_HANDLES"
bd dep add "$WRAP_BUSES" "$TEST_BDDY_SETUP"

WRAP_FADES=$(bd create "Implement handle fades and music fade helpers" \
  -p 0 \
  --type task \
  --labels core,feature-fades \
  --description "Wrap SoLoud fade APIs and add stop-after-fade scheduling for music convenience helpers. File reservations: src/play/fades.nim, src/play/handles.nim, tests/wrapper/test_fades.nim." \
  --acceptance "fadeVolume(handle,target,seconds), fadeInMusic, and fadeOutMusic work in null/nosound tests, including stop-after-fade behavior and invalid handle safety." \
  --silent)
bd dep add "$WRAP_FADES" "$WRAP_BUSES"
bd dep add "$WRAP_FADES" "$TEST_BDDY_SETUP"

WRAP_SHUTDOWN_STRESS=$(bd create "Harden shutdown ordering and resource cleanup" \
  -p 1 \
  --type task \
  --labels core,testing \
  --description "Stress repeated init/shutdown, load/play/stop cycles, and failure cleanup. File reservations: src/play/soloud.nim, src/play/assets.nim, tests/wrapper/test_shutdown_stress.nim." \
  --acceptance "Tests prove repeated lifecycle cycles do not crash or leak wrapper state, shutdown stops active voices before destroying assets, and failed loads do not poison later init." \
  --silent)
bd dep add "$WRAP_SHUTDOWN_STRESS" "$WRAP_FADES"
bd dep add "$WRAP_SHUTDOWN_STRESS" "$CORE_VOICE_LIMITS"
bd dep add "$WRAP_SHUTDOWN_STRESS" "$TEST_BDDY_SETUP"

# ========================================
# Phase 3: Nim-First Public API
# ========================================

API_TYPES=$(bd create "Design public opaque handles and asset types" \
  -p 0 \
  --type task \
  --labels api,core \
  --description "Define Sound, Music, Handle, Bus enum or equivalent opaque public types. File reservations: src/play/types.nim, src/play.nim, tests/api/test_types.nim." \
  --acceptance "Public types expose no raw pointers, have predictable copy semantics under ARC/ORC, support cheap validity checks, express deterministic asset unload/dispose semantics, and leave room for future events/parameters without breaking phase-1 API." \
  --silent)
bd dep add "$API_TYPES" "$WRAP_ASSETS"
bd dep add "$API_TYPES" "$TEST_BDDY_SETUP"

API_LIFECYCLE=$(bd create "Expose public lifecycle API" \
  -p 0 \
  --type task \
  --labels api,feature-lifecycle \
  --description "Expose init() and shutdown() through the Nim-first API. File reservations: src/play.nim, src/play/lifecycle.nim, tests/api/test_lifecycle.nim." \
  --acceptance "Game code can import play and call init() and shutdown(); lifecycle calls preserve clean shutdown ordering, report init failures clearly, and do not expose SoLoud pointers." \
  --silent)
bd dep add "$API_LIFECYCLE" "$WRAP_LIFECYCLE"
bd dep add "$API_LIFECYCLE" "$WRAP_ERRORS"
bd dep add "$API_LIFECYCLE" "$TEST_BDDY_SETUP"

API_ASSETS=$(bd create "Expose public asset loading and unloading API" \
  -p 0 \
  --type task \
  --labels api,feature-assets \
  --description "Expose loadSound(path), loadMusic(path), and deterministic asset release semantics for resident SFX and streamed music. File reservations: src/play.nim, src/play/assets.nim, tests/api/test_assets.nim." \
  --acceptance "Public API loads WAV and OGG sounds, loads streamed WAV/OGG music without fully resident long-track memory use, supports explicit or deterministic asset cleanup, and handles missing/invalid files safely." \
  --silent)
bd dep add "$API_ASSETS" "$API_TYPES"
bd dep add "$API_ASSETS" "$WRAP_ASSETS"
bd dep add "$API_ASSETS" "$TEST_BDDY_SETUP"

API_PLAYBACK=$(bd create "Expose public playback API" \
  -p 0 \
  --type task \
  --labels api,feature-playback \
  --description "Expose play(sound) -> Handle, play(sound, bus) -> Handle, and playMusic(music) -> Handle. File reservations: src/play.nim, src/play/playback.nim, tests/api/test_playback.nim." \
  --acceptance "Public API starts SFX and music playback, returns opaque handles, defaults sounds to the sfx bus, routes music to the music bus, and rejects playback before init or from invalid assets." \
  --silent)
bd dep add "$API_PLAYBACK" "$API_ASSETS"
bd dep add "$API_PLAYBACK" "$WRAP_HANDLES"
bd dep add "$API_PLAYBACK" "$WRAP_BUSES"
bd dep add "$API_PLAYBACK" "$CORE_VOICE_LIMITS"
bd dep add "$API_PLAYBACK" "$TEST_BDDY_SETUP"

API_HANDLES=$(bd create "Expose public handle operations API" \
  -p 0 \
  --type task \
  --labels api,feature-handles \
  --description "Expose pause, resume, stop, setLooping, setVolume, and handle validity checks. File reservations: src/play.nim, src/play/handles.nim, tests/api/test_handles.nim." \
  --acceptance "Public handle operations are safe for live, stopped, dead, and stolen handles; validity checks are cheap; and no raw voice IDs leak into game code." \
  --silent)
bd dep add "$API_HANDLES" "$API_PLAYBACK"
bd dep add "$API_HANDLES" "$WRAP_HANDLES"
bd dep add "$API_HANDLES" "$TEST_BDDY_SETUP"

API_BUSES=$(bd create "Expose fixed public bus volume API" \
  -p 0 \
  --type task \
  --labels api,feature-buses \
  --description "Expose the fixed music, sfx, and ui buses plus setMusicVolume, setSfxVolume, setUiVolume, and setMasterVolume. File reservations: src/play.nim, src/play/buses.nim, tests/api/test_buses.nim." \
  --acceptance "Public API has no bus creation API, supports only music/sfx/ui plus master volume, routes sounds by explicit bus at play time, and keeps bus behavior identical across target platforms." \
  --silent)
bd dep add "$API_BUSES" "$API_PLAYBACK"
bd dep add "$API_BUSES" "$WRAP_BUSES"
bd dep add "$API_BUSES" "$TEST_BDDY_SETUP"

API_FADES=$(bd create "Expose public fade API" \
  -p 0 \
  --type task \
  --labels api,feature-fades \
  --description "Expose fadeVolume(handle,target,seconds), fadeInMusic, and fadeOutMusic with stop-after-fade behavior. File reservations: src/play.nim, src/play/fades.nim, tests/api/test_fades.nim." \
  --acceptance "Public fade APIs work for music and arbitrary handles, schedule stop-after-fade where required, handle invalid/dead handles safely, and document timing expectations." \
  --silent)
bd dep add "$API_FADES" "$API_HANDLES"
bd dep add "$API_FADES" "$API_BUSES"
bd dep add "$API_FADES" "$WRAP_FADES"
bd dep add "$API_FADES" "$TEST_BDDY_SETUP"

API_FACADE=$(bd create "Assemble top-level Nim-first play API facade" \
  -p 0 \
  --type task \
  --labels api,core \
  --description "Re-export the complete phase-1 public API from src/play.nim while keeping raw/wrapper modules internal by convention. File reservations: src/play.nim, tests/api/test_public_api.nim." \
  --acceptance "Game code can import play and access exactly the phase-1 lifecycle, asset, playback, handle, bus, and fade APIs without importing SoLoud bindings or wrapper internals." \
  --silent)
bd dep add "$API_FACADE" "$API_LIFECYCLE"
bd dep add "$API_FACADE" "$API_ASSETS"
bd dep add "$API_FACADE" "$API_PLAYBACK"
bd dep add "$API_FACADE" "$API_HANDLES"
bd dep add "$API_FACADE" "$API_BUSES"
bd dep add "$API_FACADE" "$API_FADES"

API_REALTIME_REVIEW=$(bd create "Review public API for real-time safety and thread-safety" \
  -p 1 \
  --type task \
  --labels api,quality \
  --description "Audit allocations, callbacks, public API thread-safety, and no Nim runtime interaction in platform audio threads. File reservations: docs/realtime-safety.md, src/play/**, tests/stress/**." \
  --acceptance "Documentation and tests identify audio-thread boundaries, confirm no Nim code is called from SoLoud/platform callbacks, and list any remaining thread-safety constraints." \
  --silent)
bd dep add "$API_REALTIME_REVIEW" "$API_FACADE"
bd dep add "$API_REALTIME_REVIEW" "$WRAP_SHUTDOWN_STRESS"

# ========================================
# Phase 4: Fixtures and bddy Tests
# ========================================

TEST_FIXTURES=$(bd create "Create generated WAV and OGG test fixtures" \
  -p 0 \
  --type task \
  --labels testing,assets \
  --description "Generate short WAVs, short OGG, and long OGG >=60 seconds with documented licensing. File reservations: tests/fixtures/**, tools/generate_fixtures.nim, docs/licensing.md." \
  --acceptance "Fixtures are committed or reproducibly generated, small enough for the repo, license-compatible, and cover resident SFX plus streamed music tests." \
  --silent)
bd dep add "$TEST_FIXTURES" "$LICENSE_REVIEW"
bd dep add "$TEST_FIXTURES" "$TEST_BDDY_SETUP"

TEST_RAW_BINDINGS=$(bd create "Add raw binding compile and smoke tests" \
  -p 1 \
  --type task \
  --labels testing,bindings \
  --description "Test raw binding compileability and basic init/deinit with null/nosound. File reservations: tests/bindings/**, src/play/bindings/**." \
  --acceptance "Raw binding tests compile and run headlessly on host, and fail loudly if required C API symbols drift from vendored SoLoud." \
  --silent)
bd dep add "$TEST_RAW_BINDINGS" "$RAW_BINDINGS"
bd dep add "$TEST_RAW_BINDINGS" "$TEST_BDDY_SETUP"

TEST_ASSETS=$(bd create "Add wrapper tests for sound and music loading" \
  -p 1 \
  --type task \
  --labels testing,assets \
  --description "Test resident WAV/OGG sounds, streamed OGG music, missing files, invalid files, and cleanup. File reservations: tests/wrapper/test_assets.nim, tests/fixtures/**." \
  --acceptance "bddy tests cover successful and failing loadSound/loadMusic paths under null/nosound without requiring an audio device." \
  --silent)
bd dep add "$TEST_ASSETS" "$WRAP_ASSETS"
bd dep add "$TEST_ASSETS" "$TEST_FIXTURES"

TEST_HANDLES_BUSES_FADES=$(bd create "Add API tests for handles, buses, and fades" \
  -p 1 \
  --type task \
  --labels testing,api \
  --description "Test playback handles, pause/resume/stop/loop/volume, fixed bus volumes, fadeVolume, fadeInMusic, and fadeOutMusic. File reservations: tests/api/**, tests/wrapper/test_handles.nim, tests/wrapper/test_buses.nim, tests/wrapper/test_fades.nim." \
  --acceptance "Tests exercise the complete phase-1 public API surface with valid, dead, and stopped handles under null/nosound." \
  --silent)
bd dep add "$TEST_HANDLES_BUSES_FADES" "$API_FADES"
bd dep add "$TEST_HANDLES_BUSES_FADES" "$TEST_FIXTURES"

TEST_STRESS=$(bd create "Add host stress tests for lifecycle, voice limits, and rapid operations" \
  -p 2 \
  --type task \
  --labels testing,quality \
  --description "Create bounded stress tests suitable for CI using null/nosound. File reservations: tests/stress/**, src/play/**." \
  --acceptance "Stress tests cover repeated init/shutdown, rapid load/play/stop, many concurrent voices within configured limits, and no crashes under ARC/ORC." \
  --silent)
bd dep add "$TEST_STRESS" "$TEST_HANDLES_BUSES_FADES"
bd dep add "$TEST_STRESS" "$WRAP_SHUTDOWN_STRESS"

# ========================================
# Phase 5: Desktop Examples
# ========================================

EXAMPLE_SHARED=$(bd create "Create shared example utilities and asset loader" \
  -p 1 \
  --type task \
  --labels examples,setup \
  --description "Add minimal shared helpers for keyboard/input loops and locating fixture assets without adding heavy dependencies. File reservations: examples/common/**, examples/assets/**, tests/fixtures/**." \
  --acceptance "Examples can locate audio assets from repo root, run on desktop with nim c, and keep dependencies compatible with console cross-compilation." \
  --silent)
bd dep add "$EXAMPLE_SHARED" "$API_FACADE"
bd dep add "$EXAMPLE_SHARED" "$TEST_FIXTURES"

EXAMPLE_SFX=$(bd create "Build WAV SFX keypress example" \
  -p 1 \
  --type task \
  --labels examples,feature-sfx \
  --description "Create an example that plays a WAV sound effect on keypress. File reservations: examples/sfx_keypress.nim, examples/common/**." \
  --acceptance "Example initializes play, loads a WAV SFX, plays it on keypress, shuts down cleanly, and runs on the available desktop host." \
  --silent)
bd dep add "$EXAMPLE_SFX" "$EXAMPLE_SHARED"
bd dep add "$EXAMPLE_SFX" "$API_PLAYBACK"

EXAMPLE_MUSIC=$(bd create "Build streamed OGG music fade example" \
  -p 1 \
  --type task \
  --labels examples,feature-music \
  --description "Create an example that streams looping OGG music and demonstrates fade-in/fade-out. File reservations: examples/music_fades.nim, examples/common/**." \
  --acceptance "Example uses loadMusic/playMusic/fadeInMusic/fadeOutMusic, loops streamed OGG music, shuts down cleanly, and runs on the available desktop host." \
  --silent)
bd dep add "$EXAMPLE_MUSIC" "$EXAMPLE_SHARED"
bd dep add "$EXAMPLE_MUSIC" "$WRAP_FADES"

EXAMPLE_BUSES=$(bd create "Build bus volume demo example" \
  -p 1 \
  --type task \
  --labels examples,feature-buses \
  --description "Create an example demonstrating master, music, sfx, and ui volume controls. File reservations: examples/bus_volume_demo.nim, examples/common/**." \
  --acceptance "Example plays representative sounds routed through fixed buses, changes per-bus and master volume, and runs on the available desktop host." \
  --silent)
bd dep add "$EXAMPLE_BUSES" "$EXAMPLE_SHARED"
bd dep add "$EXAMPLE_BUSES" "$WRAP_BUSES"

DESKTOP_VERIFY=$(bd create "Verify desktop examples on Windows, Linux, and macOS paths" \
  -p 1 \
  --type task \
  --labels examples,testing,desktop \
  --description "Run all three examples with a real desktop backend on the available host and keep a null/nosound smoke path for CI. File reservations: docs/desktop-verification.md, scripts/build_desktop_examples.sh." \
  --acceptance "All examples build and are actually run on the available desktop host, observed behavior is recorded, instructions cover other desktop OSes, and null/nosound CI path remains headless." \
  --silent)
bd dep add "$DESKTOP_VERIFY" "$EXAMPLE_SFX"
bd dep add "$DESKTOP_VERIFY" "$EXAMPLE_MUSIC"
bd dep add "$DESKTOP_VERIFY" "$EXAMPLE_BUSES"

# ========================================
# Phase 6: Console Backend Work in SoLoud Fork
# ========================================

VITA_EVAL=$(bd create "Evaluate existing SoLoud vita_homebrew backend under VitaSDK" \
  -p 0 \
  --type task \
  --labels platform-vita,soloud,spike \
  --description "Build the existing fork backend with VitaSDK before designing any replacement. File reservations: docs/vita-backend-eval.md, vendor/soloud/** after re-vendor only. External reservation: ~/git/soloud/src/backend/vita_homebrew/**, ~/git/soloud/include/soloud*.h, ~/git/soloud/src/core/**." \
  --acceptance "Evaluation records build status, required link stubs, any failures, and whether fixes were made in birbparty/soloud before re-vendoring." \
  --silent)
bd dep add "$VITA_EVAL" "$SOLOUD_AUDIT"
bd dep add "$VITA_EVAL" "$SETUP_CONFIG"

VITA_FIXES=$(bd create "Patch SoLoud Vita backend in fork if required" \
  -p 0 \
  --type task \
  --labels platform-vita,soloud \
  --description "Apply any required VitaSDK fixes in ~/git/soloud, then re-vendor. File reservations: docs/vita-backend-fixes.md, vendor/soloud/**. External reservation: ~/git/soloud/src/backend/vita_homebrew/**, ~/git/soloud/include/soloud*.h, ~/git/soloud/src/core/**." \
  --acceptance "Vita backend compiles in the fork, changes are documented with fork commit SHA, and vendor/soloud is refreshed from that SHA." \
  --silent)
bd dep add "$VITA_FIXES" "$VITA_EVAL"

THREAD_3DS=$(bd create "Port SoLoud thread and mutex primitives to libctru in fork" \
  -p 0 \
  --type task \
  --labels platform-3ds,soloud \
  --description "Implement devkitARM/libctru support for SoLoud thread creation and mutexes in the birbparty/soloud fork. File reservations: docs/3ds-thread-port.md, vendor/soloud/** after re-vendor. External reservation: ~/git/soloud/src/core/soloud_thread*, ~/git/soloud/include/soloud_thread*.h." \
  --acceptance "SoLoud core thread/mutex code builds under devkitARM without pthreads, public C API locking remains available, and changes are documented with fork commit SHA." \
  --silent)
bd dep add "$THREAD_3DS" "$SOLOUD_AUDIT"

BACKEND_3DS_SPIKE=$(bd create "Spike 3DS NDSP backend architecture in SoLoud fork" \
  -p 0 \
  --type task \
  --labels platform-3ds,soloud,spike \
  --description "Confirm NDSP sample rate, signed16 stereo format, ring buffer sizing, dspfirm.cdc prerequisite, and SoLoud init dispatch changes. File reservations: docs/3ds-backend-design.md. External reservation planning: ~/git/soloud/src/backend/ctru_ndsp/**, ~/git/soloud/include/soloud*.h, ~/git/soloud/src/core/soloud.cpp." \
  --acceptance "Design confirms 44100 Hz SoLoud mixing into NDSP stereo channel unless disproven, documents dspfirm.cdc hardware requirement, and lists exact fork files to patch." \
  --silent)
bd dep add "$BACKEND_3DS_SPIKE" "$THREAD_3DS"

BACKEND_3DS_IMPL=$(bd create "Implement in-tree ctru_ndsp SoLoud backend in fork" \
  -p 0 \
  --type task \
  --labels platform-3ds,soloud \
  --description "Implement backend directory, enum value, C API mirror, and Soloud::init dispatch in ~/git/soloud; re-vendor after fork commit. File reservations: docs/3ds-backend-impl.md, vendor/soloud/** after re-vendor. External reservation: ~/git/soloud/src/backend/ctru_ndsp/**, ~/git/soloud/include/soloud*.h, ~/git/soloud/src/core/soloud.cpp." \
  --acceptance "devkitARM builds SoLoud with ctru_ndsp backend, backend creates its own C++/libctru audio thread, feeds NDSP wave buffers, does not enter Nim runtime, and vendor snapshot records fork SHA." \
  --silent)
bd dep add "$BACKEND_3DS_IMPL" "$BACKEND_3DS_SPIKE"

CONSOLE_REVENDOR=$(bd create "Re-vendor SoLoud after Vita and 3DS backend updates" \
  -p 0 \
  --type task \
  --labels soloud,vendor,platforms \
  --description "Refresh vendor/soloud from the fork commit containing Vita evaluation/fixes and 3DS thread/backend work. File reservations: vendor/soloud/**, docs/soloud-vendor.md." \
  --acceptance "Vendored snapshot includes required console backend changes, docs list exact fork SHA, and host raw/wrapper tests still compile." \
  --silent)
bd dep add "$CONSOLE_REVENDOR" "$VITA_FIXES"
bd dep add "$CONSOLE_REVENDOR" "$BACKEND_3DS_IMPL"

CONSOLE_BINDINGS_UPDATE=$(bd create "Update bindings and backend selection for console backend enums" \
  -p 0 \
  --type task \
  --labels bindings,platforms \
  --description "Refresh generated/handwritten bindings for SOLOUD_VITA_HOMEBREW and 3DS ctru_ndsp enum values after re-vendor. File reservations: src/play/bindings/soloud_raw.nim, src/play/backends.nim, tests/bindings/**." \
  --acceptance "Bindings expose console backend enum values under appropriate defines, host tests still pass, and console examples can select platform backends at compile time." \
  --silent)
bd dep add "$CONSOLE_BINDINGS_UPDATE" "$CONSOLE_REVENDOR"
bd dep add "$CONSOLE_BINDINGS_UPDATE" "$RAW_BINDINGS"

# ========================================
# Phase 7: Console Cross-Compilation and Human Gates
# ========================================

CROSS_3DS=$(bd create "Cross-compile tests and examples for Nintendo 3DS" \
  -p 0 \
  --type task \
  --labels platform-3ds,testing \
  --description "Use devkitARM/libctru cfg and scripts to build .3dsx examples. File reservations: nim_3ds.cfg, scripts/build_3ds_examples.sh, examples/**, docs/3ds-build.md." \
  --acceptance "All three examples cross-compile to .3dsx with -d:ds3, SoLoud uses ctru_ndsp backend, build docs mention dspfirm.cdc for real hardware, and no clckr integration is required." \
  --silent)
bd dep add "$CROSS_3DS" "$CONSOLE_BINDINGS_UPDATE"
bd dep add "$CROSS_3DS" "$EXAMPLE_SFX"
bd dep add "$CROSS_3DS" "$EXAMPLE_MUSIC"
bd dep add "$CROSS_3DS" "$EXAMPLE_BUSES"
bd dep add "$CROSS_3DS" "$SETUP_SCRIPTS"

CROSS_VITA=$(bd create "Cross-compile tests and examples for PS Vita" \
  -p 0 \
  --type task \
  --labels platform-vita,testing \
  --description "Use VitaSDK cfg and scripts to build .vpk examples. File reservations: nim_vita.cfg, scripts/build_vita_examples.sh, examples/**, docs/vita-build.md." \
  --acceptance "All three examples cross-compile to Vita artifacts with -d:vita, SoLoud uses vita_homebrew backend, and build docs list VitaSDK prerequisites and packaging commands." \
  --silent)
bd dep add "$CROSS_VITA" "$CONSOLE_BINDINGS_UPDATE"
bd dep add "$CROSS_VITA" "$EXAMPLE_SFX"
bd dep add "$CROSS_VITA" "$EXAMPLE_MUSIC"
bd dep add "$CROSS_VITA" "$EXAMPLE_BUSES"
bd dep add "$CROSS_VITA" "$SETUP_SCRIPTS"

HARDWARE_3DS=$(bd create "Human hardware gate for Nintendo 3DS audio examples" \
  -p 0 \
  --type task \
  --labels platform-3ds,hardware-gate \
  --description "Produce artifacts and instructions; user runs on real 3DS hardware and reports result. File reservations: docs/3ds-hardware-verification.md, build/3ds/**." \
  --acceptance "Gate records artifact paths, exact build command, dspfirm.cdc prerequisite, expected behavior for all three examples, hardware result, and any follow-up failures as new beads." \
  --silent)
bd dep add "$HARDWARE_3DS" "$CROSS_3DS"

HARDWARE_VITA=$(bd create "Human hardware gate for PS Vita audio examples" \
  -p 0 \
  --type task \
  --labels platform-vita,hardware-gate \
  --description "Produce artifacts and instructions; user runs on real Vita hardware and reports result. File reservations: docs/vita-hardware-verification.md, build/vita/**." \
  --acceptance "Gate records artifact paths, exact build command, expected behavior for all three examples, hardware result, and any follow-up failures as new beads." \
  --silent)
bd dep add "$HARDWARE_VITA" "$CROSS_VITA"

# ========================================
# Phase 8: CI and Packaging Verification
# ========================================

CI_DESKTOP=$(bd create "Add GitHub Actions desktop matrix" \
  -p 1 \
  --type task \
  --labels ci,desktop \
  --description "Create CI jobs for Linux, macOS, and Windows to build the package and run bddy tests. File reservations: .github/workflows/ci.yml, play.nimble, tests/**." \
  --acceptance "CI installs Nim 2.x, builds play, runs full bddy suite with null/nosound backend, captures JUnit or TAP output, and builds desktop examples." \
  --silent)
bd dep add "$CI_DESKTOP" "$TEST_STRESS"
bd dep add "$CI_DESKTOP" "$DESKTOP_VERIFY"

CI_3DS=$(bd create "Add GitHub Actions 3DS cross-compile job" \
  -p 1 \
  --type task \
  --labels ci,platform-3ds \
  --description "Use devkitpro/devkitarm Docker image to compile examples without executing them. File reservations: .github/workflows/ci.yml, scripts/build_3ds_examples.sh, nim_3ds.cfg." \
  --acceptance "CI cross-compiles all examples for 3DS, uploads or lists artifacts, and does not attempt hardware execution." \
  --silent)
bd dep add "$CI_3DS" "$CROSS_3DS"

CI_VITA=$(bd create "Add GitHub Actions Vita cross-compile job" \
  -p 1 \
  --type task \
  --labels ci,platform-vita \
  --description "Use vitasdk/vitasdk Docker image to compile examples without executing them. File reservations: .github/workflows/ci.yml, scripts/build_vita_examples.sh, nim_vita.cfg." \
  --acceptance "CI cross-compiles all examples for Vita, uploads or lists artifacts, and does not attempt hardware execution." \
  --silent)
bd dep add "$CI_VITA" "$CROSS_VITA"

PKG_NIMBLE_CONSUME=$(bd create "Verify play as URL-pinned nimble dependency" \
  -p 1 \
  --type task \
  --labels packaging,testing \
  --description "Create a throwaway consumer or documented local test that imports play through a URL or path pin. File reservations: tests/consumer/**, docs/consumption.md, play.nimble." \
  --acceptance "A minimal external Nim project can depend on play through nimble URL pinning, import play, compile a small program, and resolve vendored SoLoud paths correctly." \
  --silent)
bd dep add "$PKG_NIMBLE_CONSUME" "$API_FACADE"
bd dep add "$PKG_NIMBLE_CONSUME" "$SOLOUD_COMPILE_MODEL"

PKG_PATH_CONSUME=$(bd create "Verify play via --path injection for console-style consumers" \
  -p 1 \
  --type task \
  --labels packaging,platforms,testing \
  --description "Test clckr-style bare nim c consumption using --path injection without nimble resolution. File reservations: tests/consumer_path/**, docs/consumption.md, scripts/test_path_consumer.sh." \
  --acceptance "A minimal consumer can compile with nim c plus --path to play/src, including console cfg style, and vendored SoLoud source paths resolve from the library rather than the consumer." \
  --silent)
bd dep add "$PKG_PATH_CONSUME" "$API_FACADE"
bd dep add "$PKG_PATH_CONSUME" "$SOLOUD_COMPILE_MODEL"
bd dep add "$PKG_PATH_CONSUME" "$SETUP_SCRIPTS"

# ========================================
# Phase 9: Documentation and Release Readiness
# ========================================

DOCS_API=$(bd create "Write phase-1 public API documentation" \
  -p 1 \
  --type task \
  --labels docs,api \
  --description "Document lifecycle, assets, playback, handles, buses, fades, platform defines, and error behavior. File reservations: README.md, docs/api.md, examples/**." \
  --acceptance "Docs include concise examples for every public API group and state that game code never imports SoLoud bindings directly." \
  --silent)
bd dep add "$DOCS_API" "$API_FACADE"
bd dep add "$DOCS_API" "$API_FADES"

DOCS_PLATFORM=$(bd create "Write platform build and hardware verification docs" \
  -p 1 \
  --type task \
  --labels docs,platforms \
  --description "Document desktop, 3DS, and Vita prerequisites, build commands, artifact locations, and hardware test gates. File reservations: docs/desktop-build.md, docs/3ds-build.md, docs/vita-build.md, docs/3ds-hardware-verification.md, docs/vita-hardware-verification.md." \
  --acceptance "Docs clearly separate agent-verifiable cross-compilation from human hardware verification and mention 3DS dspfirm.cdc requirement." \
  --silent)
bd dep add "$DOCS_PLATFORM" "$CROSS_3DS"
bd dep add "$DOCS_PLATFORM" "$CROSS_VITA"

DOCS_FUTURE_SEAMS=$(bd create "Document future middleware seams without implementing them" \
  -p 2 \
  --type task \
  --labels docs,architecture \
  --description "Describe how phase-1 choices leave room for events, parameters, states, adaptive music, profiler, plugins, and visual tools. File reservations: docs/architecture.md, docs/future-roadmap.md." \
  --acceptance "Docs connect phase-1 handle/assets/bus/fade architecture to future clean-room roadmap while explicitly marking future systems as out of scope." \
  --silent)
bd dep add "$DOCS_FUTURE_SEAMS" "$API_REALTIME_REVIEW"

FINAL_ACCEPTANCE=$(bd create "Phase-1 acceptance verification for play" \
  -p 0 \
  --type task \
  --labels release,acceptance \
  --description "Final integration bead for phase-1 done criteria. File reservations: docs/release-checklist.md, README.md, .github/workflows/ci.yml." \
  --acceptance "All bddy tests pass on host null/nosound, desktop examples run, 3DS and Vita examples cross-compile, hardware gates are completed or have explicit reported blockers, CI is green, and docs cover consumption modes." \
  --silent)
bd dep add "$FINAL_ACCEPTANCE" "$CI_DESKTOP"
bd dep add "$FINAL_ACCEPTANCE" "$CI_3DS"
bd dep add "$FINAL_ACCEPTANCE" "$CI_VITA"
bd dep add "$FINAL_ACCEPTANCE" "$PKG_NIMBLE_CONSUME"
bd dep add "$FINAL_ACCEPTANCE" "$PKG_PATH_CONSUME"
bd dep add "$FINAL_ACCEPTANCE" "$HARDWARE_3DS"
bd dep add "$FINAL_ACCEPTANCE" "$HARDWARE_VITA"
bd dep add "$FINAL_ACCEPTANCE" "$DOCS_API"
bd dep add "$FINAL_ACCEPTANCE" "$DOCS_PLATFORM"
bd dep add "$FINAL_ACCEPTANCE" "$DOCS_FUTURE_SEAMS"

echo ""
echo "Bead graph created. Next commands:"
echo "  bd ready"
echo "  bd graph"
echo "  bd list --label setup"
