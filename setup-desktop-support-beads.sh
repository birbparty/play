#!/bin/bash
# Project: play
# Change: Full desktop audio support (Windows, Linux, macOS) via SoLoud miniaudio
# Generated: 2026-06-19
#
# Enables a real audible desktop backend (WITH_MINIAUDIO) where the desktop
# build currently links only headless NOSOUND/NULL. Primarily a build-system +
# backend-source-selection change; the Phase-1 public API already abstracts
# backend selection.
#
# Grounded seams (verified against source 2026-06-19):
#   - src/play/private/soloud_sources.nim  desktop `else` branches at L30-31
#     (passC), L33-34 (passL -lstdc++), L71-73 (compile nosound/null). Console
#     branches L26-29, L67-70, L103-104 must stay byte-for-byte untouched.
#   - src/play/backends.nim                platformDefaultBackend()/initOptions()
#     -> SOLOUD_AUTO for desktop (L56-77). Headless hazard lives here.
#   - src/play/backend.nim                 info/pump only; no backend-id accessor.
#     Soloud_getBackendId/String exist in bindings/soloud_raw.nim L53-54.
#   - src/play/lifecycle.nim               activeBackend reports running backend
#     automatically; no change expected.
#   - examples/phase1_public_api.nim:9     init(initOptions()) = AUTO, run in BOTH
#     smoke and audio paths (build_desktop_examples.sh L59 & L66).
#   - .github/workflows/ci.yml L19-22      matrix = ubuntu/macos/windows; reduce
#     to ubuntu-latest only and add libasound2-dev.
#
# CAUTION (file reservations for parallel agents):
#   - src/play/private/soloud_sources.nim is shared by ALL platform branches.
#     Desktop edits are additive in the `else`/host-OS-guarded blocks ONLY.
#     High contention with any Vita/3DS work.
#   - Do NOT touch nim_3ds.cfg / nim_vita.cfg. Console builds do not auto-read
#     them; desktop link flags go in guarded passL of soloud_sources.nim, never
#     as bare flags in nim.cfg.

set -e

# Initialize beads if needed
if [ ! -d ".beads" ]; then
    bd init
fi

echo "Creating desktop-support beads..."

# ========================================
# Phase 1: Analysis & Preparation (gates impl)
# ========================================

DECIDE_HEADLESS=$(bd create "Decide device-free backend strategy for smoke/CI (forced-NULL vs real->NULL fallback)" \
  -d "CRITICAL design decision, must precede enabling miniaudio. Today AUTO resolves to NOSOUND/NULL only because those are the only compiled backends. Once WITH_MINIAUDIO compiles, AUTO will try to open a real device; on a headless CI runner this hangs/errors and SoLoud init returns an error rather than falling back. Decide ONE: (a) explicit real->NULL fallback in the init path, or (b) force NULL on the smoke/CI path via env var / -d: define / explicit initOptions(backend=nullBackend). Seam: src/play/backends.nim platformDefaultBackend()/initOptions() L56-77; trigger path examples/phase1_public_api.nim:9 (AUTO, unconditional) run by scripts/build_desktop_examples.sh L59 & L66 -> ci.yml L43. Record the decision in the bead notes; impl beads depend on it." \
  -p 0 -l analysis -t decision --silent)

DECIDE_BACKEND_ACCESSOR=$(bd create "Decide scope: add backend-id/name accessor to backend.nim for 'report real backend' criterion" \
  -d "Success criterion says activeBackend reports the real desktop backend (miniaudio) at runtime. activeBackend (src/play/lifecycle.nim + private/lifecycle.nim) already reports the running backend with no change. Decide whether the criterion ALSO requires a human-readable backend name/id accessor on src/play/backend.nim (info API). If yes, it can wrap Soloud_getBackendId / Soloud_getBackendString (already declared in src/play/bindings/soloud_raw.nim L53-54). backend.nim today has NO backend-id accessor. Output: yes/no + intended signature; gates the optional accessor impl bead." \
  -p 0 -l analysis -t decision --silent)

CAPTURE_BASELINE=$(bd create "Capture console-branch baseline + run Vita/3DS nim check guards green before any change" \
  -d "Record a byte-for-byte snapshot of the console when-branches in src/play/private/soloud_sources.nim (L26-29 passC, L67-70 compile, L103-104 openmpt stub) so the post-change regression task can diff them. Run the existing guards green as a baseline: 'nim check --path:src -d:playPlatformVita tests/bindings/test_soloud_raw.nim', same with -d:playPlatform3ds, and the test_backends.nim equivalents (ci.yml L71-87). This is the pre-change side of the MUST-NOT-break-console constraint." \
  -p 0 -l prep -t task --silent)

CHAR_DESKTOP=$(bd create "Characterize current desktop NOSOUND/NULL behavior + confirm desktop examples use >=440Hz fixtures" \
  -d "Before enabling miniaudio, capture current desktop behavior on the headless path: build+run scripts/build_desktop_examples.sh --smoke and record output, and note what activeBackend reports today (NOSOUND/NULL). Confirm the desktop examples/probe actually load the >=440Hz fixtures (tests/fixtures/generated/tone_music.ogg / tone_sfx.wav; see fixtures README and the hardware-verification gotcha: 220Hz sines are inaudible on small speakers and previously burned verification rounds). Flag now if any desktop example still points at a sub-440Hz tone." \
  -p 1 -l prep -t task --silent)
bd dep add $CHAR_DESKTOP $CAPTURE_BASELINE

# ========================================
# Phase 2: Core Implementation
# ========================================

IMPL_MINIAUDIO=$(bd create "Add WITH_MINIAUDIO passC + compile soloud_miniaudio.cpp in desktop else branch of soloud_sources.nim" \
  -d "In src/play/private/soloud_sources.nim, desktop else branch only: add -DWITH_MINIAUDIO to the passC at L30-31 (additive; keep -DWITH_NOSOUND -DWITH_NULL so the NULL/NOSOUND backends remain available for the device-free path) and add compileSoloud backend/miniaudio/soloud_miniaudio.cpp in the desktop else of the backend block at L71-73. soloud_miniaudio.cpp #includes the header-only miniaudio.h (already vendored). Preserve the static {.compile.} model. Console branches (L26-29, L67-70, L103-104) MUST stay byte-for-byte unchanged. Do NOT re-vendor or bump the birbparty/soloud feat/3ds-support fork." \
  -p 0 -l impl -t feature --silent)
bd dep add $IMPL_MINIAUDIO $DECIDE_HEADLESS
bd dep add $IMPL_MINIAUDIO $CAPTURE_BASELINE

IMPL_LINKFLAGS=$(bd create "Add guarded desktop passL link flags for miniaudio (per-OS) in soloud_sources.nim" \
  -d "Co-locate with the existing 'when defined(linux): passL \"-lstdc++\"' at src/play/private/soloud_sources.nim L33-34, guarded by 'when defined(playPlatformDesktop) and defined(<os>)'. Linux: -ldl -lpthread -lm (load-bearing; miniaudio dlopen's libasound/libpulse at RUNTIME so -lasound at link time is NOT required -- treat as optional/verify-on-target). macOS: -framework CoreAudio -framework AudioToolbox -framework CoreFoundation. Windows: -lole32 -lwinmm. Do NOT put these in nim.cfg (read by every nim c/check including console guards). Keep all flags here so rollback is a single guarded block." \
  -p 0 -l impl -t feature --silent)
bd dep add $IMPL_LINKFLAGS $IMPL_MINIAUDIO

IMPL_DEVICEFREE=$(bd create "Implement the device-free path chosen in the headless decision (forced-NULL or real->NULL fallback)" \
  -d "Implement the strategy decided in the headless-strategy bead so the smoke/CI path opens NO real device once miniaudio is compiled. Touch points depending on the choice: src/play/backends.nim (initOptions/platformDefaultBackend, e.g. a -d: define or env gate that selects nullBackend) and/or examples/phase1_public_api.nim:9 (which calls AUTO unconditionally and runs in BOTH smoke and audio modes). Must NOT regress the audible --audio path: with a device present, AUTO must still resolve to miniaudio. Keep the change minimal and guarded." \
  -p 0 -l impl -t feature --silent)
bd dep add $IMPL_DEVICEFREE $DECIDE_HEADLESS
bd dep add $IMPL_DEVICEFREE $IMPL_MINIAUDIO

IMPL_BACKEND_ACCESSOR=$(bd create "(Conditional) Add backend-id/name accessor to backend.nim over Soloud_getBackendId/String" \
  -d "ONLY if the accessor-scope decision says yes. Add an accessor on src/play/backend.nim (info API) wrapping raw.Soloud_getBackendId and/or raw.Soloud_getBackendString (declared in src/play/bindings/soloud_raw.nim L53-54), following the currentEngine()/rawHandle()/nil-guard pattern of backendSamplerate() (backend.nim L7-15). Add a unit test asserting it returns NULL/NOSOUND on the device-free path. If the decision says no, close this bead as not-needed." \
  -p 1 -l impl -t feature --silent)
bd dep add $IMPL_BACKEND_ACCESSOR $DECIDE_BACKEND_ACCESSOR
bd dep add $IMPL_BACKEND_ACCESSOR $IMPL_MINIAUDIO

# ========================================
# Phase 3: Build / CI / Examples
# ========================================

CI_MATRIX=$(bd create "Reduce CI desktop matrix to ubuntu-latest only and add libasound2-dev install step" \
  -d "In .github/workflows/ci.yml: remove macos-latest and windows-latest from the desktop matrix (L19-22), leaving ubuntu-latest only -- do NOT leave a half-removed matrix or orphaned 'if: matrix.os ==' branches (clean up the windows-only/non-windows conditional steps at L95-142). Add a step to apt-get install -y libasound2-dev BEFORE the build (the desktop job has no ALSA-headers install today; the only apt-get is in the 3DS container job). Leave the nintendo-3ds-examples and vita-examples jobs unchanged. macOS/Windows are verified manually off-CI." \
  -p 0 -l impl -t task --silent)
bd dep add $CI_MATRIX $IMPL_MINIAUDIO
bd dep add $CI_MATRIX $IMPL_DEVICEFREE

SCRIPT_SMOKE=$(bd create "Ensure build_desktop_examples.sh --smoke stays device-free and --audio is audible" \
  -d "Verify/adjust scripts/build_desktop_examples.sh so --smoke (L58-63) forces the device-free backend per the chosen strategy (phase1_public_api at L59 currently runs AUTO with no flag) and --audio (L65-70) produces real miniaudio output on a machine with a device. The real backend is linked by compiling soloud_miniaudio.cpp, NOT by the --audio flag (which only selects initOptions). Keep scripts/common.sh examples array intact." \
  -p 1 -l impl -t task --silent)
bd dep add $SCRIPT_SMOKE $IMPL_DEVICEFREE

COMPILE_GUARD=$(bd create "Add desktop-backend compile-guard test proving miniaudio compiles" \
  -d "Add/extend a test (mirror tests/test_soloud_compile.nim, ci.yml L63) that compiles the desktop closure with WITH_MINIAUDIO so CI proves the miniaudio backend builds (header-only miniaudio.h + soloud_miniaudio.cpp) on ubuntu with libasound2-dev present. This is the build-proof half of the success criteria; no device required." \
  -p 1 -l testing -t task --silent)
bd dep add $COMPILE_GUARD $IMPL_MINIAUDIO
bd dep add $COMPILE_GUARD $IMPL_LINKFLAGS

# ========================================
# Phase 4: Testing & Regression
# ========================================

TEST_DEVICEFREE=$(bd create "Verify full host test suite + smoke pass on the device-free NULL path (CI green)" \
  -d "Run the device-free smoke/test suite end to end as CI will: scripts/build_desktop_examples.sh --smoke, nimble test / tests/test_all.nim, the binding+backend tests (ci.yml L63-98). Confirm no hang and no device is opened with miniaudio compiled but the device-free path active. Confirm activeBackend reports NULL/NOSOUND on this path." \
  -p 0 -l testing -t task --silent)
bd dep add $TEST_DEVICEFREE $IMPL_DEVICEFREE
bd dep add $TEST_DEVICEFREE $SCRIPT_SMOKE
bd dep add $TEST_DEVICEFREE $CI_MATRIX

REGRESS_CONSOLE=$(bd create "Regression: re-run Vita/3DS nim check guards green AND diff console branches byte-for-byte" \
  -d "Re-run the guards from ci.yml L71-87 (nim check -d:playPlatformVita and -d:playPlatform3ds on tests/bindings/test_soloud_raw.nim and tests/bindings/test_backends.nim) and confirm green. Diff the console when-branches in src/play/private/soloud_sources.nim (L26-29, L67-70, L103-104) against the pre-change baseline snapshot -- they MUST be byte-for-byte identical. This is the verified 'keep console green' constraint, not an assertion." \
  -p 0 -l testing -t task --silent)
bd dep add $REGRESS_CONSOLE $IMPL_MINIAUDIO
bd dep add $REGRESS_CONSOLE $IMPL_LINKFLAGS
bd dep add $REGRESS_CONSOLE $CAPTURE_BASELINE

# ========================================
# Phase 5: Manual hardware verification (audible)
# ========================================

VERIFY_DOC=$(bd create "Write manual audible-verification checklist in docs/desktop-verification.md (mirror 3ds record format)" \
  -d "Author a concrete checklist in docs/desktop-verification.md mirroring docs/3ds-hardware-verification.md: who runs it, exact binary/command (scripts/build_desktop_examples.sh --audio, which example/probe), the EXPECTED pitch/pattern of the >=440Hz fixtures stated explicitly IN the checklist (per the gotcha: never rely on prose elsewhere -- inaudible 220Hz tones with valid handles burned prior rounds), and a recorded pass/fail sign-off with observer + date per OS. Cover Linux, macOS, Windows." \
  -p 1 -l docs -t task --silent)
bd dep add $VERIFY_DOC $IMPL_LINKFLAGS
bd dep add $VERIFY_DOC $SCRIPT_SMOKE

VERIFY_LINUX=$(bd create "Human audible verification on Linux (miniaudio, recognizable >=440Hz tone, sign-off)" \
  -d "On a Linux desktop with a sound card, run scripts/build_desktop_examples.sh --audio per the checklist. Confirm AUDIBLE output (not silence), confirm activeBackend reports the real miniaudio backend (not NULL/NOSOUND), record observer + date pass/fail in docs/desktop-verification.md. Expected pitch/pattern per the checklist." \
  -p 1 -l testing -t task --silent)
bd dep add $VERIFY_LINUX $VERIFY_DOC
bd dep add $VERIFY_LINUX $TEST_DEVICEFREE

VERIFY_MACOS=$(bd create "Human audible verification on macOS (CoreAudio via miniaudio, sign-off)" \
  -d "On macOS, run scripts/build_desktop_examples.sh --audio per the checklist. Confirm AUDIBLE >=440Hz output, activeBackend reports real miniaudio backend, frameworks (CoreAudio/AudioToolbox/CoreFoundation) link correctly. Record observer + date pass/fail in docs/desktop-verification.md." \
  -p 1 -l testing -t task --silent)
bd dep add $VERIFY_MACOS $VERIFY_DOC

VERIFY_WINDOWS=$(bd create "Human audible verification on Windows (WASAPI via miniaudio, sign-off)" \
  -d "On Windows, run scripts/build_desktop_examples.sh --audio per the checklist. Confirm AUDIBLE >=440Hz output, activeBackend reports real miniaudio backend, ole32/winmm link correctly. Record observer + date pass/fail in docs/desktop-verification.md." \
  -p 1 -l testing -t task --silent)
bd dep add $VERIFY_WINDOWS $VERIFY_DOC

# ========================================
# Phase 6: Documentation & Cleanup
# ========================================

DOCS_UPDATE=$(bd create "Update desktop docs: ALSA-headers build prereq, runtime dlopen model, new backend" \
  -d "Update docs/desktop-build.md (build-time prerequisite: libasound2-dev / alsa/asoundlib.h on Linux; the runtime dlopen model -- miniaudio dlopen's libasound/libpulse, CoreAudio, WASAPI; NOT statically linked), docs/desktop-verification.md (link to the manual protocol), and docs/soloud-vendor-audit.md (miniaudio now compiled on desktop; was NOSOUND+NULL only). Note the constraint is 'no bundled third-party runtime libs', not 'zero OS audio deps'." \
  -p 2 -l docs -t task --silent)
bd dep add $DOCS_UPDATE $IMPL_MINIAUDIO
bd dep add $DOCS_UPDATE $IMPL_LINKFLAGS

ROLLBACK_DOC=$(bd create "Document single-block rollback for the desktop backend" \
  -d "Document (in docs/desktop-build.md or a ROLLBACK note) that reverting desktop audio = removing -DWITH_MINIAUDIO from the passC, the soloud_miniaudio.cpp compileSoloud line, and the guarded desktop passL flags in src/play/private/soloud_sources.nim, after which desktop falls back to NOSOUND/NULL. Verify the change is cleanly revertible as one guarded block with no link flags scattered into nim.cfg or other files." \
  -p 2 -l cleanup -t task --silent)
bd dep add $ROLLBACK_DOC $IMPL_MINIAUDIO
bd dep add $ROLLBACK_DOC $IMPL_LINKFLAGS
bd dep add $ROLLBACK_DOC $IMPL_DEVICEFREE

echo ""
echo "Desktop-support bead graph created. View with:"
echo "  bd ready    # unblocked tasks (should show the two decisions + baseline)"
echo "  bd dep tree # full dependency tree"
echo "  bd dep cycles  # confirm no cycles"
