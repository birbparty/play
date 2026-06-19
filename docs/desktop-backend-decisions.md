# Desktop Backend — Design Decisions

Decision records made before enabling the desktop miniaudio backend
(`WITH_MINIAUDIO`). These gate the implementation beads and are the source of
truth the impl/verification tasks build on.

All claims below were grounded against the real source on 2026-06-19 (iteration
52, branch off `main`).

---

## D1 — Device-free backend strategy for smoke/CI (play-fw7)

**Decision: force the NULL backend on the smoke/CI path (option b). Do NOT add an
automatic real→NULL fallback to the library `init` path (option a is rejected).**

### Context (grounded)

- `examples/phase1_public_api.nim:9` calls `init(initOptions())` unconditionally.
  `initOptions()` (`src/play/backends.nim:64`) defaults `backend` to
  `platformDefaultBackend()` (`backends.nim:56`), which on desktop returns
  `defaultBackend = Backend(SOLOUD_AUTO)` (`backends.nim:27,61-62`).
- Today AUTO resolves to NOSOUND/NULL only because those are the only compiled
  backends. Once `WITH_MINIAUDIO` is compiled (play-xxu), AUTO will resolve to
  miniaudio (`SOLOUD_MINIAUDIO = 15`, `soloud_raw.nim:28`) and try to open a real
  device.
- On `init` failure, `Soloud_initEx` returns non-zero and play surfaces a
  `PlayResult` **failure** — it does not crash and does not fall back
  (`src/play/private/lifecycle.nim:184-193`, `failedInit` at `:98-110`). The
  example then logs and `return`s (`phase1_public_api.nim:9-12`), so a headless
  smoke run would either **hang** opening an ALSA device or pass **vacuously**
  having exercised nothing.
- The smoke path runs `examples/phase1_public_api` in CI via
  `scripts/build_desktop_examples.sh --smoke` (`script L58-59`) →
  `.github/workflows/ci.yml:42-43`.

### Why force-NULL, not a library fallback

- An automatic real→NULL fallback changes `init` semantics for **every** desktop
  consumer: a real user with a broken/absent audio device would silently get
  no sound and no error, masking exactly the failure they need to see. That is a
  bad default for an audio library.
- A library fallback also makes the CI smoke test pass via the fallback rather
  than deterministically exercising a known device-free backend — the smoke test
  would no longer assert what backend it ran on.
- Forcing NULL on the smoke/CI path keeps library semantics honest (real desktop
  users get AUTO→miniaudio and a real error if no device) while making CI
  deterministic and device-free. The existing `pumpAudio()`
  (`src/play/backend.nim:35`) already exists precisely to drive a NULL/noSound
  backend in tests, so this aligns with current test infrastructure.

### Recommended mechanism (for play-sx9 to implement)

A **desktop-only environment-variable override** honored by backend selection,
set by the CI smoke step and by `build_desktop_examples.sh --smoke`:

- Proposed env var: `PLAY_FORCE_NULL_BACKEND` (any non-empty value ⇒ force
  `nullBackend`).
- Honored in `platformDefaultBackend()` (`backends.nim:56`) under the desktop
  branch only — guard so the override is compiled **out** of the
  `playPlatformVita` / `playPlatform3ds` arms and never affects console targets.
- CI sets `PLAY_FORCE_NULL_BACKEND=1` on the `--smoke` step; the `--audio` path
  leaves it unset so AUTO→miniaudio stays audible.

**Why an env var rather than a `-d:` compile define or per-call
`initOptions(backend=nullBackend)`:**

- `examples/phase1_public_api` is **built once** and run in **both** the
  `--smoke` and `--audio` modes (`build_desktop_examples.sh:59` and `:66` both run
  it). A compile-time `-d:playForceNullBackend` cannot differentiate the two runs
  of the same binary; a runtime switch can.
- Hardcoding `initOptions(backend = nullBackend)` in the example would force NULL
  even in `--audio` mode, defeating audible verification.
- Reading a desktop audio-driver override from the environment is idiomatic for
  audio backends (cf. `SDL_AUDIODRIVER`), and centralizing it in
  `platformDefaultBackend()` keeps the switch in one guarded place.

### Consequence for downstream beads

- **play-sx9** implements this env-var override + wires the CI/`--smoke` step.
- **play-xxu** (enable miniaudio) must land with play-sx9 (or after it) so CI
  never runs AUTO→miniaudio on a headless runner.
- **play-4gh** verifies the full host suite + smoke pass green on the forced-NULL
  path.

---

## D2 — Backend reporting accessor scope (play-fnc)

**Decision: YES — add a thin human-readable `activeBackendName*(): string`
accessor to `src/play/backend.nim` over `Soloud_getBackendString`. play-gge stays
open as the implementation of this accessor (it is NOT closed as not-needed).**

### Context (grounded)

- `activeBackend()` already exists: `src/play/lifecycle.nim:40` →
  `src/play/private/lifecycle.nim:230-234`, returning `Backend` (a
  `distinct cuint`) from `Soloud_getBackendId`. It reports whatever backend the
  running engine actually selected, so it needs no change to report miniaudio.
- `SOLOUD_MINIAUDIO = 15` and `SOLOUD_NULLDRIVER = 17` already exist
  (`src/play/bindings/soloud_raw.nim:28,30`), so an **enum comparison is
  technically sufficient** for an automated assertion.
- `Soloud_getBackendString` (`soloud_raw.nim:54`) returns a human-readable
  `cstring` for the active backend; `backend.nim` exposes no wrapper over it
  today.

### Why add the string accessor anyway

The enum check covers the automated assertion, but the success criterion
"`activeBackend` reports the real desktop backend" is verified largely by a
**human** following the `docs/desktop-verification.md` checklist (play-5gx,
play-apf / play-f3r / play-nd0). Per the project's verification-clarity gotcha
(the 220Hz-inaudible miss), verifiers must be given an **unambiguous** signal —
reading the opaque integer `15` invites mistakes; reading a string like
`MiniAudio` / `NULL` does not. A thin wrapper directly serves the human criterion.

### How the criterion is verified (output required by play-fnc)

- **Automated (device present):** assert
  `activeBackend() == Backend(SOLOUD_MINIAUDIO)` (id `15`). On the device-free
  path, assert `activeBackend() == nullBackend` (id `17`,
  `backends.nim:29`). Optionally add a named `miniaudioBackend*` const in
  `backends.nim` for readability.
- **Human (checklist):** read and record `activeBackendName()` — expected to read
  as SoLoud's miniaudio backend string (record the exact observed value; SoLoud
  reports miniaudio as `MiniAudio`). The checklist must state the expected string
  so a mismatch (e.g. `NULL`) is obvious.

### Proposed signature (for play-gge)

```nim
proc activeBackendName*(): string =
  ## Human-readable name of the active audio backend (e.g. "MiniAudio", "NULL"),
  ## or "" when the engine is not initialized.
```

Implemented in `src/play/backend.nim` alongside the other info accessors,
guarding the uninitialized case the same way `backendSamplerate()` does
(`backend.nim:7-15`): return `""` when `currentEngine()` / `rawHandle()` is nil,
otherwise `$raw.Soloud_getBackendString(soloud)`.

### Consequence for downstream beads

- **play-gge** stays open; implement `activeBackendName()` per the signature
  above (P1, not blocking the miniaudio enable itself).
- **play-5gx** (verification checklist) references `activeBackendName()` for the
  human read and the `activeBackend() == miniaudio` enum assert for the automated
  check.
