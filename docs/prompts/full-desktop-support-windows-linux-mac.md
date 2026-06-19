# Big Change Planning with Beads

## Agent Instructions

You are an expert software architect creating a comprehensive task breakdown for a change to an existing codebase. This task graph will be executed by AI agents working in parallel, coordinated through MCP Agent Mail with file reservations to prevent conflicts.

<quality_expectations>
Create a thorough, production-ready task graph. Include all necessary analysis, preparation, implementation, testing, and documentation tasks. Go beyond the basics — consider edge cases, error handling, security considerations, backwards compatibility, and integration points. Each task should be specific enough for an agent to execute independently without ambiguity.
</quality_expectations>

<critical_constraint>
You must NOT implement any of the changes yourself. Your ONLY output is a bash shell script containing `bd create` and `bd dep add` commands. Do NOT use `bd add` — the correct command is `bd create`. Do not write code. Do not create files other than the shell script. Do not modify existing files. Read and analyze the codebase, then produce the script.
</critical_constraint>

## Change Information

### Change Type
NEW_FEATURE

Enabling SoLoud's desktop hardware audio backends. The desktop build path currently links only headless backends (`NOSOUND` + `NULL`) for CI; this change adds real audible audio output on Windows, Linux, and macOS. The Phase-1 public API already abstracts backend selection, so this is primarily a build-system + backend-source-selection change rather than an API change.

### Description
Add full desktop support for Windows, Linux, and macOS — i.e. real, audible audio output on all three desktop operating systems. Today the desktop target compiles but only links headless backends (`NOSOUND`/`NULL`); the console targets (PS Vita via `WITH_VITA_HOMEBREW`, Nintendo 3DS via `WITH_CTRU_NDSP`) are the only ones with working hardware audio. This change enables a genuine desktop audio backend so `play` produces sound on a developer/end-user desktop machine.

### Links to Relevant Documentation

**Recommended backend strategy — miniaudio (`WITH_MINIAUDIO`):**
miniaudio is SoLoud's default and recommended cross-platform backend. A single compile define (`WITH_MINIAUDIO`) plus `vendor/soloud/src/backend/miniaudio/soloud_miniaudio.cpp` (which `#include`s the header-only `miniaudio.h`) internally selects WASAPI on Windows, CoreAudio on macOS, and ALSA/PulseAudio on Linux at runtime. This is the lowest-friction path to all three OSes from one code path and is the recommended approach for this change. Native per-platform backends (`wasapi`, `coreaudio`, `alsa`) are also vendored and remain available if finer control is later desired.

**Vendored backend sources (already present — no re-vendoring needed):**
- `vendor/soloud/src/backend/miniaudio/soloud_miniaudio.cpp` + `miniaudio.h` (primary)
- `vendor/soloud/src/backend/wasapi/` (Windows native fallback)
- `vendor/soloud/src/backend/coreaudio/` (macOS native fallback)
- `vendor/soloud/src/backend/alsa/` (Linux native fallback)

**Per-OS link requirements (for miniaudio):**
- Linux: `-ldl -lpthread -lm` are the load-bearing flags. miniaudio **dlopen's** libasound/libpulse at runtime, so `-lasound` at *link* time is NOT strictly required by miniaudio itself — treat `-lasound` as optional/verify-on-target rather than mandatory. The ALSA **dev headers** (`libasound2-dev`, `alsa/asoundlib.h`) ARE required at build time for the miniaudio ALSA path to compile.
- macOS: link the `CoreAudio`, `AudioToolbox`, `CoreFoundation` frameworks (`-framework CoreAudio -framework AudioToolbox -framework CoreFoundation`).
- Windows: link `ole32`, `winmm` (miniaudio's WASAPI path).

**Where the link flags belong (verified seam):** `src/play/private/soloud_sources.nim` already establishes the OS-conditional `passL` precedent — line 33-34: `when defined(linux): {.passL: "-lstdc++".}`. Add the desktop link flags here, co-located with and guarded the same way as the new `WITH_MINIAUDIO` `passC` define, NOT as bare flags in `nim.cfg`. `nim.cfg` is the default config Nim auto-reads for EVERY `nim c`/`nim check` invocation — including the Vita/3DS `nim check` compile guards — so unconditional flags there would leak into the console builds. Guard with `when defined(playPlatformDesktop) and defined(linux)` / `and defined(macosx)` / `and defined(windows)`.

**Backend reporting (verified):** `activeBackend` lives in `src/play/lifecycle.nim` (and `src/play/private/lifecycle.nim`), NOT in `backend.nim`. It reads whatever backend the running engine actually selected, so it needs no code change — it will report the real backend automatically once `SOLOUD_AUTO` resolves to miniaudio. `src/play/backends.nim` (plural) holds `platformDefaultBackend()` / `initOptions()` (selection). `src/play/backend.nim` (singular) is backend *info/pump* API only (`backendSamplerate`, `backendBufferSize`, `outputLatency`, `pumpAudio`) — it has NO backend-id accessor today. If the success criterion "backend info reports the real desktop backend" requires surfacing a backend name/id, an accessor over `Soloud_getBackendId`/`Soloud_getBackendString` may need to be ADDED to `backend.nim` (confirm scope before creating that bead).

**External reference URLs (verified June 2026):**
- SoLoud backends overview: https://solhsa.com/soloud/backends.html
- SoLoud quickstart (how backend defines work): https://solhsa.com/soloud/quickstart.html
- miniaudio backend source upstream: https://github.com/jarikomppa/soloud/blob/master/src/backend/miniaudio/soloud_miniaudio.cpp

**Internal project docs to consult and update:**
- `docs/soloud-vendor-audit.md` — backend inventory (notes 13 desktop backends available, only NOSOUND+NULL compiled today)
- `docs/desktop-build.md` — current smoke/audio example build modes
- `docs/desktop-verification.md` — currently notes hardware backends not yet added
- `docs/ROADMAP.md`, `docs/architecture.md` — phase context and middleware seams
- `docs/realtime-safety.md` — Nim/C callback boundary audit (relevant: audio callback runs on a C/C++ thread)

**Existing seams a future implementer must respect:**
- `src/play/private/soloud_sources.nim` — `when defined(playPlatform3ds)` / `defined(playPlatformVita)` / else `{.compile.}` blocks selecting backend sources. The desktop `else` branch is where `WITH_MINIAUDIO` + `soloud_miniaudio.cpp` get added.
- `src/play/backends.nim` / `src/play/backend.nim` — backend enum, `platformDefaultBackend()`, `activeBackend`, `initOptions()` already abstract selection.
- `config.nims` maps `-d:ds3`→`playPlatform3ds`, `-d:vita`→`playPlatformVita`, default→`playPlatformDesktop`.
- `nim.cfg` / `nim_3ds.cfg` / `nim_vita.cfg` — per-target compile/link config. **WARNING:** `nim.cfg` is the default config read by every `nim c`/`nim check`, including the console compile guards; console builds do NOT auto-read `nim_3ds.cfg`/`nim_vita.cfg`. Therefore desktop link flags must NOT go as bare flags into `nim.cfg` — put them in the guarded `passL` block of `soloud_sources.nim` (see above), or guard them explicitly in `nim.cfg` with `when defined(playPlatformDesktop)`.

**Headless / no-audio-device hazard (CRITICAL — must be designed for):** Backend selection flows `initOptions()` → `SOLOUD_AUTO` (`backends.nim`). Today AUTO resolves to NOSOUND/NULL only because those are the only compiled backends. Once `WITH_MINIAUDIO` is compiled, **AUTO will resolve to miniaudio and attempt to open a real audio device.** The CI `--smoke` path (`scripts/build_desktop_examples.sh:59` → `ci.yml:43`) runs `examples/phase1_public_api.nim`, which calls `init(initOptions())` = AUTO **unconditionally** (`phase1_public_api.nim:9`). On a headless Linux CI runner with no sound card, this will hang or fail. SoLoud's `init` returns an error rather than falling back, so a real→NULL fallback must be implemented explicitly, OR the smoke/CI path must force the NULL backend (via env var / `-d:` define / explicit `initOptions(backend = nullBackend)`). This decision must be made BEFORE enabling miniaudio, and the smoke path must stay device-free.

### Affected Areas
- `src/play/private/soloud_sources.nim` — add `WITH_MINIAUDIO` to the desktop (`else`) `passC` branch (line 30-31) + compile `soloud_miniaudio.cpp` in the desktop `else` backend branch (line 67-73) + add the guarded desktop `passL` link flags (next to the existing `when defined(linux): passL "-lstdc++"` at line 33-34). Console (`playPlatform3ds`/`playPlatformVita`) branches at lines 26-37, 67-73, 103-106 must stay byte-for-byte untouched.
- `src/play/backends.nim` — `platformDefaultBackend()` / `initOptions()` (backend *selection*). Decide whether desktop default stays `SOLOUD_AUTO` or gains a forced-NULL path for headless CI.
- `src/play/backend.nim` — info/pump API only; may need a backend-id/name accessor added IF the "report the real backend" criterion requires it (confirm scope).
- `src/play/lifecycle.nim` / `src/play/private/lifecycle.nim` — `activeBackend` lives here; reports the running backend automatically, no change expected.
- `examples/phase1_public_api.nim` — calls AUTO `init` unconditionally and runs in the CI `--smoke` path; must be made device-free for CI (force NULL, or rely on a fallback).
- `src/play/voices.nim` — desktop voice limit is already 16 (`desktopDefaultMaxActiveVoices*`); verify no regression.
- `scripts/build_desktop_examples.sh`, `scripts/common.sh` — NOTE: the real backend is linked by compiling `soloud_miniaudio.cpp` in `soloud_sources.nim`, NOT by the `--audio` flag (the flag only selects `initOptions()`). Once miniaudio is compiled, `--audio` becomes audible with no script change; the script work is ensuring the `--smoke` path forces a device-free backend.
- `.github/workflows/ci.yml` — **reduce the desktop matrix to `ubuntu-latest` only** (remove `macos-latest` and `windows-latest` from the matrix at lines 19-22 for now); add an `apt-get install -y libasound2-dev` step to the Linux desktop job (the desktop matrix has no ALSA-headers install today — the only `apt-get` is in the 3DS container job). Keep the Vita/3DS `nim check` guard jobs unchanged. macOS/Windows are verified manually off-CI.
- Tests: host smoke tests must continue to pass on the device-free NULL path; add/keep a desktop-backend compile guard that proves miniaudio compiles.
- `docs/desktop-build.md`, `docs/desktop-verification.md`, `docs/soloud-vendor-audit.md` — document the new desktop backend, the build-time ALSA-headers prerequisite, the runtime dlopen model, and the manual macOS/Windows audible-verification protocol.
- `vendor/soloud/src/backend/miniaudio` (primary), with `wasapi`/`coreaudio`/`alsa` available as native fallbacks.

### Success Criteria
- Audible audio output is verified by a human on **each** of Windows, Linux, and macOS (the existing desktop examples / audio probe play a recognizable tone or music, not silence). Per the project's hardware-verification gotcha, **fixtures must be ≥440Hz** and the verifier is explicitly told the expected pitch/pattern (this instruction must live inside the verification checklist task, not only in prose — the 220Hz-inaudible mistake burned prior console verification rounds). Confirm desktop examples actually use the ≥440Hz fixtures.
- The manual macOS/Windows verification follows a concrete checklist in `docs/desktop-verification.md`: who runs it, which binary/command (`scripts/build_desktop_examples.sh --audio`, which example/probe), expected tones, and a recorded pass/fail sign-off with observer + date (mirror the existing `docs/3ds-hardware-verification.md` record format).
- The desktop examples build in `--audio` mode and produce real hardware output (miniaudio, not `NULL`/`NOSOUND`) on all three OSes when run on a machine with an audio device.
- `activeBackend` reports the real desktop backend (miniaudio) at runtime when a device is present, not a headless one.
- **The device-free path still works:** on a headless machine / CI runner with no audio device, the smoke path runs to completion without hanging or erroring (forced-NULL or real→NULL fallback), and CI stays green.
- CI is **reduced to `ubuntu-latest` only** for the desktop job; it installs `libasound2-dev`, compiles the miniaudio backend (proving it builds), and runs the device-free smoke/test suite green. The `macos-latest`/`windows-latest` desktop runners are removed for now.
- The full existing test suite (`nimble test`), including the Vita (`-d:playPlatformVita`) and 3DS (`-d:playPlatform3ds`) `nim check` compile guards, still passes; the console `when` branches in `soloud_sources.nim` are confirmed unchanged.
- Desktop docs are updated with the build-time ALSA-headers prerequisite, the runtime dlopen dependency model, and the manual-verification protocol.

### Constraints
- **MUST NOT break PS Vita (`WITH_VITA_HOMEBREW`) or Nintendo 3DS (`WITH_CTRU_NDSP`) support.** All desktop changes must be guarded by `when defined(playPlatformDesktop)` (or equivalent host-OS conditionals) so the console `when` branches in `src/play/private/soloud_sources.nim` (lines 26-37, 67-73, 103-106) and the console `.cfg` files are completely unaffected. The change must include an explicit regression task that re-runs the Vita/3DS `nim check` guards (per `ci.yml`) AND confirms the console branches are byte-for-byte unchanged — "keep them green" must be a verified task, not an assertion.
- Preserve the static-compile model already used for vendored SoLoud (`{.compile.}` of C/C++ sources) — miniaudio compiles in exactly the same way (header-only `miniaudio.h` + `soloud_miniaudio.cpp`). **Refined runtime-dependency model:** miniaudio dlopen's the host OS audio libraries at runtime (libasound/libpulse on Linux, CoreAudio on macOS, WASAPI on Windows). This is expected and unavoidable — do NOT attempt to statically link libasound. The constraint is "no bundled third-party runtime libs," NOT "zero OS audio deps"; the build-time requirement is the ALSA dev *headers* on Linux.
- Keep the SoLoud fork pin intact (`birbparty/soloud`, branch `feat/3ds-support`); do not re-vendor or bump the fork for this change — the needed backend sources are already present.
- **CI is reduced to `ubuntu-latest` only** for the desktop job (the existing `macos-latest`/`windows-latest` desktop runners are removed for now); macOS/Windows are verified manually off-CI. Do not leave a broken/half-removed matrix.
- Respect the realtime-safety boundary: Nim code stays on the application thread, audio callbacks stay in C/C++ (see `docs/realtime-safety.md`). miniaudio's callback runs on its own C thread.
- **Rollback:** keep the change cleanly revertible as a single guarded block — reverting = removing `WITH_MINIAUDIO`, the miniaudio `{.compile.}` line, and the desktop `passL` flags, after which desktop falls back to NOSOUND/NULL. Do not scatter link flags across files. Include an explicit rollback task documenting this.

---

## Your Task

Analyze this codebase change and create a comprehensive **Beads task graph** using the `bd` CLI. Beads provides dependency-aware, conflict-free task management for multi-agent execution.

Before creating the task graph, you MUST first analyze the affected areas of the codebase:

1. Check `docs/specs/` and `docs/adr/` for existing architectural decisions
2. Examine the directory/module structure of the affected areas listed above
3. Identify key interfaces, APIs, and integration points that must be preserved
4. Note existing test patterns and coverage in the affected areas
5. Assess risk areas where changes could break existing functionality

Use your analysis to make each bead specific — reference actual file paths, module names, and patterns you observed.

Then generate a shell script that creates the complete task graph.

**IMPORTANT: Your ONLY deliverable is a bash shell script with `bd create` commands. Not an implementation plan. Not a design document. Not a code review. A runnable `.sh` script.**

---

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
# Change: Refactor auth middleware for compliance
# Generated: 2026-06-19

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating change beads..."

# ========================================
# Phase 1: Analysis & Preparation
# ========================================

ANALYZE_CURRENT=$(bd create "Analyze current auth middleware implementation in src/auth/ — document all session token storage patterns and consumer dependencies" -p 0 --label analysis --silent)

IDENTIFY_DEPS=$(bd create "Map all modules importing from src/auth/ and catalog their usage patterns" -p 0 --label analysis --silent)

CHAR_TESTS=$(bd create "Add characterization tests capturing current auth middleware behavior before refactoring" -p 0 --label prep --silent)
bd dep add $CHAR_TESTS $ANALYZE_CURRENT

# ========================================
# Phase 2: Core Implementation
# ========================================

IMPL_NEW_STORAGE=$(bd create "Implement compliant session token storage in src/auth/session.ts replacing in-memory store" -p 0 --label impl --silent)
bd dep add $IMPL_NEW_STORAGE $CHAR_TESTS
bd dep add $IMPL_NEW_STORAGE $IDENTIFY_DEPS

IMPL_MIGRATION=$(bd create "Create migration script for existing session data to new storage format" -p 1 --label impl --silent)
bd dep add $IMPL_MIGRATION $IMPL_NEW_STORAGE

UPDATE_CONSUMERS=$(bd create "Update all consumer modules to use new auth middleware API surface" -p 1 --label impl --silent)
bd dep add $UPDATE_CONSUMERS $IMPL_NEW_STORAGE

# ========================================
# Phase 3: Testing & Validation
# ========================================

UNIT_TESTS=$(bd create "Add unit tests for new session storage implementation" -p 1 --label testing --silent)
bd dep add $UNIT_TESTS $IMPL_NEW_STORAGE

INTEGRATION_TESTS=$(bd create "Add integration tests for auth flow end-to-end with new middleware" -p 1 --label testing --silent)
bd dep add $INTEGRATION_TESTS $UPDATE_CONSUMERS

REGRESSION_CHECK=$(bd create "Run full regression suite and verify characterization tests still pass" -p 0 --label testing --silent)
bd dep add $REGRESSION_CHECK $INTEGRATION_TESTS
bd dep add $REGRESSION_CHECK $UNIT_TESTS

# ========================================
# Phase 4: Cleanup & Documentation
# ========================================

UPDATE_DOCS=$(bd create "Update auth middleware documentation and API reference" -p 2 --label docs --silent)
bd dep add $UPDATE_DOCS $REGRESSION_CHECK

CLEANUP=$(bd create "Remove deprecated session storage code and update changelog" -p 3 --label cleanup --silent)
bd dep add $CLEANUP $REGRESSION_CHECK

echo ""
echo "Bead graph created! View with:"
echo "  bd ready              # List unblocked tasks"
```

---

## Bead Creation Guidelines

### Priority Levels
- `-p 0` = Critical (blocking other work, or high-risk changes needing early validation)
- `-p 1` = High (important implementation work)
- `-p 2` = Medium (standard work)
- `-p 3` = Low (cleanup, nice-to-haves)

### Labels (Phase Grouping)
Use `--label` to group beads by phase:
- `analysis` - Understanding current state
- `prep` - Preparation work (characterization tests, feature flags, scaffolding)
- `impl` - Core implementation
- `testing` - Test coverage
- `migration` - Data/code migration
- `docs` - Documentation updates
- `cleanup` - Post-rollout cleanup

### Dependency Rules
1. Never create cycles
2. Analysis tasks should complete before implementation begins
3. Characterization tests should exist before changing code
4. Use `bd dep add CHILD PARENT` (child depends on parent completing first)
5. Parallel work should share a common ancestor, not depend on each other

### Task Granularity
- Each bead should be completable in **under 750 lines of code changed**
- Tasks should be atomic enough for one agent to complete without coordination
- If a task requires multiple file areas, consider splitting by file area

---

## Change-Specific Considerations

### For New Features
- Start with analysis of similar existing features
- Consider feature flag for gradual rollout
- Plan for A/B testing if relevant
- Include documentation and changelog updates

### For Refactors
- Add characterization tests first (capture current behavior)
- Consider strangler fig pattern for large changes
- Plan incremental migration path
- Ensure no behavior changes unless intentional

### For Migrations
- Create rollback plan as an explicit task
- Plan data validation checkpoints
- Consider dual-write period if applicable
- Include monitoring/alerting tasks

### For Performance Changes
- Add benchmarks before and after
- Include load testing tasks
- Plan gradual rollout with monitoring
- Have rollback criteria defined

---

## File Reservation Planning

For each major work area, note the file patterns that will need exclusive reservation:

```bash
# Example reservation notes (add as bead descriptions)
# CAUTION: src/play/private/soloud_sources.nim is shared by ALL platform branches —
#   desktop edits must be additive in the `else` branch only; high contention with any
#   Vita/3DS work. Keep changes minimal and guarded.
# Build config: nim.cfg / config.nims — host-OS link flags; coordinate so console .cfg
#   files (nim_3ds.cfg, nim_vita.cfg) are never touched.
# Examples/scripts: scripts/build_desktop_examples.sh, scripts/common.sh
# CI: .github/workflows/ci.yml (Linux job only)
```

This helps agents claim appropriate file surfaces when they start work.

---

## Verification Steps

After generating the script:

1. **Run it**: `chmod +x setup-beads.sh && ./setup-beads.sh`
2. **Check ready work**: `bd ready` should show initial analysis/prep tasks

---

## Completeness Checklist

Ensure your task graph includes:

- [ ] Analysis of current implementation in affected areas
- [ ] Characterization tests for existing behavior
- [ ] Feature flag or gradual rollout mechanism (if applicable)
- [ ] Core implementation broken into small units
- [ ] Unit tests for new/changed code
- [ ] Integration tests for affected workflows
- [ ] Regression testing plan
- [ ] Documentation updates
- [ ] Migration scripts (if data changes)
- [ ] Rollback plan
- [ ] Cleanup tasks for post-rollout
- [ ] Clear dependency chains with no cycles
