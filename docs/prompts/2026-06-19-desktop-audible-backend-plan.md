# Plan: desktop audible-backend trilogy (CoreAudio fix + NOSOUND detection + CI gate)

Addresses three companion requests in
`~/.agents/projects/play/requests/2026-06-19-*`:

1. `macos-native-coreaudio-backend` — compile SoLoud's native CoreAudio backend
   on macOS instead of miniaudio (fixes silent AUTO→NOSOUND on Apple Silicon).
2. `detect-silent-nosound-fallback` — give consumers a discoverable way to tell
   a silent NOSOUND fallback from a real device after `init(AUTO)`.
3. `desktop-audible-backend-ci-gate` — CI asserts desktop AUTO resolves to an
   audible backend so the fix cannot silently regress.

## Grounding (verified against source on this M-series Mac)

- Working tree already carries the validated CoreAudio patch in
  `src/play/private/soloud_sources.nim` (the `M` file). A local
  `init(initOptions())` with this change resolves to **CoreAudio**
  (`backendString == "CoreAudio"`, `activeBackend() == noSoundBackend` → false).
- `config.nims:12` auto-defines `playPlatformDesktop` for any in-repo build, so
  the macOS `passL` frameworks link without callers passing `-d:` explicitly.
- `src/play/backends.nim`: `noSoundBackend`, `nullBackend`, `defaultBackend`,
  `Backend`, `==` all exist and are re-exported via `play/lifecycle` → `play`.
- `src/play/private/lifecycle.nim:230` `activeBackend(engine)` returns
  `Backend(Soloud_getBackendId(handle))`; returns `defaultBackend` when not
  initialized.
- `src/play/backend.nim` already imports `private/global_engine`,
  `private/lifecycle`, and `bindings/soloud_raw as raw`, and uses the
  `currentEngine()/rawHandle()` accessor pattern.
- `soloud_raw.nim:54` binds `Soloud_getBackendString`. There is **no**
  `SOLOUD_COREAUDIO` const yet; SoLoud's enum (`vendor/soloud/include/soloud.h`)
  gives `COREAUDIO = 11`, `MINIAUDIO = 15`, `NOSOUND = 16`, `NULLDRIVER = 17`.
- `tests/test_desktop_backend_compile.nim` is the existing device-free
  compile-guard pattern: request a specific backend non-AUTO and assert the
  result is not `NOT_IMPLEMENTED` (== 6).

## Request 1 — macOS CoreAudio backend

**Status: already applied** to `src/play/private/soloud_sources.nim` and verified
to build + resolve audibly locally. No further code change; keep the bare
`elif defined(macosx)` arms (matches the surrounding `passC`/`compileSoloud`
host-OS style; the `passL` block keeps its own `playPlatformDesktop and
defined(macosx)` guard). Vita/3DS arms untouched.

Action: commit this change as part of the branch; re-verify it builds and that a
desktop example still links on macOS.

## Request 2 — detect silent NOSOUND fallback

Add two public procs to `src/play/backend.nim` (natural home: it already owns
backend-info accessors and the engine/raw plumbing). Re-exported automatically
via `play.nim` (`export backend`).

```nim
import play/backends            # add: noSoundBackend, nullBackend, Backend, ==
import play/lifecycle as ll     # NO — would create import cycle; use activeBackend(engine) instead
```

Implementation (no new imports beyond `play/backends` for the backend consts):

```nim
proc backendString*(): string =
  ## Name of the resolved audio backend ("CoreAudio", "MiniAudio", "NoSound",
  ## "NULL", ...), or "" when the engine is not initialized. Thin wrapper over
  ## SoLoud's Soloud_getBackendString — useful for logging what AUTO selected.
  let engine = currentEngine()
  if engine == nil: return ""
  let soloud = engine.rawHandle()
  if soloud == nil: return ""
  let s = raw.Soloud_getBackendString(soloud)
  if s == nil: "" else: $s

proc isAudibleBackend*(): bool =
  ## True when the resolved backend can actually produce sound — i.e. it is
  ## NOT the silent NoSound fallback or the NULL driver. Implemented as a
  ## denylist so audible console backends (Vita/3DS homebrew) are not misreported.
  ## Returns false when the engine is not initialized.
  let engine = currentEngine()
  if engine == nil: return false
  let b = engine.activeBackend()      # private/lifecycle: Backend(getBackendId)
  b != noSoundBackend and b != nullBackend
```

Notes:
- `backend.nim` must import `play/backends` to get `noSoundBackend`/`nullBackend`
  and the `==` operator. `engine.activeBackend()` comes from the already-imported
  `private/lifecycle`. No cycle: `backends` only imports `soloud_raw`.
- Denylist (not allowlist) per the request — `== coreaudio/miniaudio` would
  wrongly flag Vita/3DS homebrew as silent.
- `isAudibleBackend()` is false when uninitialized (no engine = no sound), which
  also makes the "did init give me a device?" check correct without a separate
  init guard.

### Docs (Request 2)
- `docs/api.md` Lifecycle section: document `isAudibleBackend()` and
  `backendString()`, with a note that `init(AUTO).ok == true` does **not** imply
  audible output (AUTO can resolve to NOSOUND) and the recommended post-init
  check.
- `docs/consumption.md`: short "verify you got an audible device" note showing
  `discard init(initOptions()); doAssert isAudibleBackend()`.

### Tests (Request 2)
- New `tests/api/audible_backend_spec.nim` (follow existing `tests/api/*_spec.nim`
  harness): with `init(initOptions(backend = nullBackend))` → `isAudibleBackend()
  == false` and `backendString()` non-empty; with `noSoundBackend` →
  `isAudibleBackend() == false`; uninitialized → `isAudibleBackend() == false`
  and `backendString() == ""`. Wire into `tests/test_all.nim` if specs are
  aggregated there (check how the api specs are included).

## Request 3 — CI gate

Add a `SOLOUD_COREAUDIO* = 11'u32` const to `soloud_raw.nim` (needed by the
macOS compile guard; keep the numeric ordering with the other backend ids).

New self-contained test `tests/test_desktop_audible_backend.nim` with two parts:

- **Part A — compiled-backend-set guard (always on, device-free).** Mirrors
  `test_desktop_backend_compile.nim`. On macOS request `SOLOUD_COREAUDIO`
  non-AUTO and assert result != `NOT_IMPLEMENTED` (proves `WITH_COREAUDIO`
  compiled). On other desktop OSes request `SOLOUD_MINIAUDIO` and assert the
  same (proves `WITH_MINIAUDIO`). This catches a dropped/mis-`when`'d backend arm
  with no device required.
- **Part B — audible AUTO assertion (gated by env).** `init(initOptions())`
  (AUTO) then, when `PLAY_REQUIRE_AUDIBLE=1` is set in the environment,
  `doAssert isAudibleBackend()` (and log `backendString()`); otherwise just log
  the resolved backend for diagnostics and do not fail. This makes macOS a hard
  gate (runners have CoreAudio) while keeping ubuntu/windows informational where
  a device may be absent.

CI workflow (`.github/workflows/ci.yml`): add a new job
`desktop-audible-backend` (separate from the ubuntu `desktop` job to avoid
sprinkling `if: runner.os` over every Linux-specific step, e.g. ALSA install and
the miniaudio guard). Matrix via `include`:

- `macos-latest` with `require_audible: "1"` (hard gate).
- `windows-latest` with `require_audible: ""` and `continue-on-error: true`
  (best-effort per the request — windows runner audio is less certain).

Job steps: checkout → setup-nim → show toolchain → build desktop examples
(`build_desktop_examples.sh --smoke`, proves the closure compiles on that OS) →
run `nim c --path:src -r tests/test_desktop_audible_backend.nim` with
`PLAY_REQUIRE_AUDIBLE: ${{ matrix.require_audible }}`.

Leave the existing ubuntu `desktop` job (null smoke + miniaudio compile guard)
**unchanged** for pure code-path/compile coverage, per the request's "keep the
device-free smoke as-is".

Update the stale comment block at the top of the `desktop` job that says
macOS/Windows are "verified manually off-CI and are NOT exercised here".

## Verification

- `nim c --path:src -r tests/api/audible_backend_spec.nim` (or via test_all).
- `nim c --path:src -r tests/test_desktop_audible_backend.nim` locally on macOS
  with `PLAY_REQUIRE_AUDIBLE=1` (expect CoreAudio, pass) and without (logs).
- `bash scripts/build_desktop_examples.sh --smoke` still green.
- `nim check --path:src -d:playPlatformVita tests/bindings/test_backends.nim` and
  the 3ds variant — confirm the new `SOLOUD_COREAUDIO` const and backend.nim
  changes don't break console checks.
- Full `nim c --path:src -r tests/test_all.nim`.
- Run `/review` (dual Opus) before commit, then `/fix-review`.

## Review reconciliation (two Opus reviews, 2026-06-19)

Both reviewers verified the plan is grounded and buildable (no Critical/Important
correctness defects; no import cycle; console `nim check` unaffected by the new
`SOLOUD_COREAUDIO` const). Actionable findings applied:

- **Helper placement.** Keep BOTH `isAudibleBackend()` and `backendString()` in
  `backend.nim` (it is literally the "Backend info" module — co-locating the pair
  is the most discoverable surface). Drop the plan's misleading "import cycle"
  note: there is no cycle because `backend.nim` uses the private
  `engine.activeBackend()` it already imports, not the lifecycle facade.
- **`isAudibleBackend()` uses explicit `!=`, not a set.** `Backend` is
  `distinct cuint` (uint32) — too wide for a Nim `set`, so the request's
  `notin {nullBackend, noSoundBackend}` pseudocode would not compile. Use
  `b != noSoundBackend and b != nullBackend`.
- **Uninitialized guard.** Guard on `engine.rawHandle() == nil` (nil when not
  initialized) before reading the backend id, so an allocated-but-not-initialized
  engine — whose private `activeBackend()` returns `defaultBackend`/AUTO — is
  reported as not audible, not accidentally `true`.
- **Exact SoLoud backend strings** (verified in vendor source): `"CoreAudio"`,
  `"MiniAudio"`, `"NoSound"`, `"null driver"` (lowercase). Document these
  verbatim; do not promise `"NULL"`/`"NullDriver"`.
- **macOS CI gate.** Keep the hard `PLAY_REQUIRE_AUDIBLE=1` assertion (the request
  asks for it); the PR's own macOS CI run is the trial before it reaches `main`.
  Add a workflow comment documenting the rollback lever (set `require_audible: ""`
  to demote macOS to informational) and keep Part A (compiled-set guard) running
  first/always so a Part-B device flake never masks compile-guard regressions.
- **Stale comments.** Update both the `desktop`-job header comment AND
  `soloud_sources.nim:50-52` ("CI runs ubuntu-latest only") once macOS is in CI.
- **Why not `build_desktop_examples.sh --audio`.** Those four example binaries
  play sound but assert nothing about the backend — they pass silently on
  NOSOUND, i.e. the exact bug. A test asserting `isAudibleBackend()` is the real
  gate; `--smoke` stays for compile coverage.
- **Wire `tests/api/audible_backend_spec.nim` into `tests/test_all.nim`** (api
  specs are aggregated by import there).

## Out of scope / non-goals

- No change to `init` fallback/error semantics (play's D1 decision stands;
  fix is observability + native backend only).
- No vendored-miniaudio bump.
- Linux/Windows keep miniaudio.
```
