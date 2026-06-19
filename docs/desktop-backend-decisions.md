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
  (`src/play/private/lifecycle.nim:184-193`, `failedInit` at `:98-111`). The
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

### Chosen mechanism (implemented in play-sx9)

Pin `nullBackend` directly in the one unprotected example,
`examples/phase1_public_api.nim`, mirroring the established sibling pattern — do
**NOT** add an env var, a `-d:` define, or any change to
`platformDefaultBackend()` / `initOptions()` in `backends.nim`.

```nim
when defined(playPlatform3ds) or defined(playPlatformVita):
  let options = initOptions()                       # console: real backend via AUTO
else:
  let options = initOptions(backend = nullBackend)  # desktop: device-free
let initResult = init(options)
```

This is the same shape `bus_volume_demo` / `music_fades` / `sfx_keypress` already
use in their default config (`bus_volume_demo.nim:20-23`, etc.): console keeps its
real backend through AUTO, desktop pins `nullBackend`.

**Why the per-example pin, and not the env-var override originally sketched
here:** the env-var idea rested on the premise that `phase1_public_api` is built
once and run in **both** `--smoke` and `--audio` modes, needing a runtime switch
to stay audible under `--audio`. That premise is false:
`build_desktop_examples.sh` runs `phase1_public_api` with **no `--audio` flag in
either** mode (`script:59` smoke, `script:66` audio) — it is purely an
API-surface smoke exercise and is never meant to be audible. With nothing to
differentiate at runtime, the simplest correct fix is to pin `nullBackend`
unconditionally on the desktop arm. This also avoids the costs the env-var path
carried: no `import std/os` (which `backends.nim` does not have and which would
need console-gating), no env-var read in the library core, and no CI env wiring.

**Blast radius:** `--smoke` runs four examples (`script:59-62`). The other three
already pin `nullBackend` on their desktop `else:` arm
(`bus_volume_demo.nim:23`, `music_fades.nim:24`, `sfx_keypress.nim:27`) and only
go AUTO under an explicit `--audio` arg. `phase1_public_api` was the sole
bare-AUTO caller; after this change all four smoke binaries are device-free on
desktop. Any **new** smoke example must likewise pin `nullBackend` on its no-flag
desktop arm rather than rely on a bare `initOptions()`.

> **Audible verification is unaffected.** Real desktop audio output is verified
> through the other three examples run with `--audio` (which resolve AUTO →
> miniaudio once play-xxu compiles it). `phase1_public_api` is not part of the
> audible-verification surface.

### Consequence for downstream beads

- **play-sx9** pins `nullBackend` in `phase1_public_api` (done). No `backends.nim`
  / CI / env changes.
- **play-xxu** (enable miniaudio) must land with play-sx9 (or after it) so CI
  never runs AUTO→miniaudio on a headless runner.
- **play-4gh** verifies the full host suite + smoke pass green on the device-free
  NULL path.
- **play-d8q** owns keeping `--smoke` device-free and `--audio` audible end-to-end.

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
`MiniAudio` / `null driver` does not. A thin wrapper directly serves the human
criterion.

### Exact backend strings (grounded against vendored SoLoud)

`Soloud_getBackendString` returns the backend's `mBackendString`, set verbatim by
each backend's `init`. The real values in the vendored fork are **case- and
spacing-sensitive** — the checklist must use these exact strings, not a
paraphrase:

| Backend | `mBackendString` | Source |
|---|---|---|
| miniaudio | `MiniAudio` | `vendor/soloud/src/backend/miniaudio/soloud_miniaudio.cpp:84` |
| null driver | `null driver` | `vendor/soloud/src/backend/null/soloud_null.cpp:53` |
| nosound | `NoSound` | `vendor/soloud/src/backend/nosound/soloud_nosound.cpp:114` |

Note the device-free smoke path (D1) forces the **null** backend, so its expected
string is `null driver` (lowercase, with a space) — **not** `NULL`. A checklist
that expects `NULL` would raise a false mismatch on exactly the path D1
establishes. These strings are vendored-version-dependent, so play-gge / play-5gx
must **record the observed value** and treat the table above as the expected
baseline, re-confirming it if the SoLoud fork is ever bumped.

### How the criterion is verified (output required by play-fnc)

- **Automated (device present):** assert
  `activeBackend() == Backend(SOLOUD_MINIAUDIO)` (id `15`). On the device-free
  path, assert `activeBackend() == nullBackend` (id `17`,
  `backends.nim:29`). Add a named `miniaudioBackend* = Backend(SOLOUD_MINIAUDIO)`
  const to `backends.nim` (firm, not optional) so the assert reads
  `activeBackend() == miniaudioBackend` — matching the existing
  `vitaHomebrewBackend` / `ctruNdspBackend` named-const idiom
  (`backends.nim:33,36`).
- **Human (checklist):** read and record `activeBackendName()`; expected
  `MiniAudio` on a device, `null driver` on the forced-NULL path (see the table
  above). The checklist must print the expected string so a mismatch is obvious.

### Proposed implementation (for play-gge — copy-paste ready)

Mirror `backendSamplerate()` (`backend.nim:7-15`), with **two** guards — the
uninitialized engine AND a nil `cstring`. The latter matters because
`mBackendString` is initialized to `0` in core (`soloud.cpp:125,217`) and only
assigned by a backend's `init`; if `Soloud_initEx` fails (the desktop
AUTO→miniaudio-with-no-device case D1 is built around), the engine can be
non-nil while the backend string is still nil, and `$` on a nil `cstring` must
not be reached:

```nim
proc activeBackendName*(): string =
  ## Human-readable name of the active audio backend (e.g. "MiniAudio",
  ## "null driver"), or "" when the engine is not initialized or has no backend.
  let engine = currentEngine()
  if engine == nil:
    return ""
  let soloud = engine.rawHandle()
  if soloud == nil:
    return ""
  let s = raw.Soloud_getBackendString(soloud)
  if s == nil:
    return ""
  $s
```

### Consequence for downstream beads

- **play-gge** stays open; implement `activeBackendName()` per the signature
  above (P1, not blocking the miniaudio enable itself).
- **play-5gx** (verification checklist) references `activeBackendName()` for the
  human read and the `activeBackend() == miniaudio` enum assert for the automated
  check.
