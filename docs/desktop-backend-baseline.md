# Desktop Backend Change — Pre-Change Baseline (play-5z6)

This file is the **pre-change snapshot** captured before enabling the desktop
miniaudio backend (`WITH_MINIAUDIO`). It exists so the regression task
(**play-6h6**) can confirm — byte-for-byte — that the Nintendo 3DS
(`WITH_CTRU_NDSP`) and PS Vita (`WITH_VITA_HOMEBREW`) console branches in
`src/play/private/soloud_sources.nim` are **completely unchanged** by the desktop
work. The desktop `else:` arms *are* expected to change; the console arms are not.

Captured on the iteration branch off `main` **before** any desktop edit
(play-xxu / play-f5z) lands.

> Snapshots are anchored by **content**, not line number — line numbers shift
> once play-xxu adds the desktop miniaudio compile line. Re-locate each block by
> its anchor text below, never by the line numbers shown here (those are
> informational only, accurate as of this capture).

---

## 1. Console when-branches — verbatim snapshot

### Anchor A — backend `passC` define block

Locate by the line `when defined(playPlatform3ds):` immediately followed by the
`-DWITH_CTRU_NDSP` `passC`. The `else:` arm (desktop) is where `WITH_MINIAUDIO`
gets added; the `3ds`/`vita` arms must stay frozen.

```nim
when defined(playPlatform3ds):
  {.passC: "-DWITH_CTRU_NDSP".}
elif defined(playPlatformVita):
  {.passC: "-DWITH_VITA_HOMEBREW".}
else:
  {.passC: "-DWITH_NOSOUND -DWITH_NULL".}
```

### Anchor A2 — console C++ flags block (console-only, frozen in full)

Locate by `when defined(playPlatform3ds) or defined(playPlatformVita):`
immediately followed by the `-fno-exceptions` `passC`. This block has no desktop
arm and must remain byte-for-byte identical.

```nim
when defined(playPlatform3ds) or defined(playPlatformVita):
  {.passC: "-fno-exceptions -fno-rtti -std=gnu++11".}
```

### Anchor B — backend source compile block

Locate by the comment `# Backends enabled by the WITH_* defines above.`. The
`else:` arm (desktop) gains the `soloud_miniaudio.cpp` compile line; the
`3ds`/`vita` arms must stay frozen.

```nim
# Backends enabled by the WITH_* defines above.
when defined(playPlatform3ds):
  compileSoloud "backend/ctru_ndsp/soloud_ctru_ndsp.cpp"
elif defined(playPlatformVita):
  compileSoloud "backend/vita_homebrew/soloud_vita_homebrew.cpp"
else:
  compileSoloud "backend/nosound/soloud_nosound.cpp"
  compileSoloud "backend/null/soloud_null.cpp"
```

### Anchor C — OpenMPT stub block

Locate by the **second** `when defined(playPlatform3ds) or defined(playPlatformVita):`
in the file (the one whose body is `{.compile: sourceDir / "soloud_openmpt_stub.c".}`).
The console arm must stay frozen.

```nim
when defined(playPlatform3ds) or defined(playPlatformVita):
  {.compile: sourceDir / "soloud_openmpt_stub.c".}
else:
  compileSoloud "audiosource/openmpt/soloud_openmpt_dll.c"
```

---

## 2. Frozen-line digest (for byte-for-byte regression)

The console arms that **must not change** are the lines below (the 3ds/vita arms
and the two console-only `when` blocks — the desktop `else:` arms are excluded
because they legitimately change):

```
when defined(playPlatform3ds):
  {.passC: "-DWITH_CTRU_NDSP".}
elif defined(playPlatformVita):
  {.passC: "-DWITH_VITA_HOMEBREW".}
when defined(playPlatform3ds) or defined(playPlatformVita):
  {.passC: "-fno-exceptions -fno-rtti -std=gnu++11".}
when defined(playPlatform3ds):
  compileSoloud "backend/ctru_ndsp/soloud_ctru_ndsp.cpp"
elif defined(playPlatformVita):
  compileSoloud "backend/vita_homebrew/soloud_vita_homebrew.cpp"
when defined(playPlatform3ds) or defined(playPlatformVita):
  {.compile: sourceDir / "soloud_openmpt_stub.c".}
```

**play-6h6 verification recipe** — re-run this exact command on the post-change
tree and confirm the digest matches:

```bash
grep -E 'playPlatform3ds|playPlatformVita|WITH_CTRU_NDSP|WITH_VITA_HOMEBREW|fno-exceptions|ctru_ndsp/soloud_ctru_ndsp|vita_homebrew/soloud_vita_homebrew|soloud_openmpt_stub' \
  src/play/private/soloud_sources.nim | shasum -a 256
```

| Artifact | SHA-256 (pre-change baseline) |
|---|---|
| Console frozen-line extract (command above) | `d485539d56b9fb709047d635ab471857fd00feaad09ade61e9ea60c59cc02c41` |
| Full `soloud_sources.nim` (reference only — *will* change) | `fc0bbbdcb42fe9e9d341c56b6fb2bcc4ff8902be8fd8fa9b1d3c29adfd529397` |

If the console frozen-line digest differs after the desktop change, the console
branches were disturbed — investigate before merging.

---

## 3. Green guard baseline — Vita/3DS `nim check`

These are the **exact four** compile-guard commands from `.github/workflows/ci.yml`
(steps "JUnit Vita binding checks", "JUnit 3DS binding checks", "JUnit Vita
backend checks", "JUnit 3DS backend checks"). They run under the default
`nim.cfg` (no `nim_vita.cfg` / `nim_3ds.cfg` is copied for these checks) — which
is exactly why desktop link flags must live in the guarded `passL` block of
`soloud_sources.nim` and **never** as bare flags in `nim.cfg` (they would leak
into these console guards).

| # | Command | Pre-change result |
|---|---|---|
| 1 | `nim check --path:src -d:playPlatformVita tests/bindings/test_soloud_raw.nim` | ✅ `SuccessX` (exit 0) |
| 2 | `nim check --path:src -d:playPlatform3ds tests/bindings/test_soloud_raw.nim` | ✅ `SuccessX` (exit 0) |
| 3 | `nim check --path:src -d:playPlatformVita tests/bindings/test_backends.nim` | ✅ `SuccessX` (exit 0) |
| 4 | `nim check --path:src -d:playPlatform3ds tests/bindings/test_backends.nim` | ✅ `SuccessX` (exit 0) |

Captured with Nim 2.2.10 (macOS arm64). All four exited `0` with a final
`[SuccessX]` hint and no errors. This is the green baseline play-6h6 must
reproduce after the desktop change lands.
