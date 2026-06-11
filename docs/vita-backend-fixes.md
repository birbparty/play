# SoLoud Vita Backend Fix Decision

This records the outcome for `play-hby`, the conditional task to patch the
SoLoud `vita_homebrew` backend in the fork if the VitaSDK evaluation required
backend changes.

## Decision

No birbparty/soloud fork patch is required for the current Vita backend
evaluation.

`docs/vita-backend-eval.md` showed, within a compile/archive/minimal-link smoke
evaluation, that the vendored `vita_homebrew` backend from fork commit
`412011ec5c950ebf85f717b57722bb9298329686` compiles with VitaSDK, can be
included in a static SoLoud archive, and links into a minimal Vita smoke ELF
when `-lpthread` is added to the Vita runtime link group.

This was a VitaSDK compile/link decision only; hardware audio behavior remains
part of later Play integration or example-build validation.

Because the backend builds as-is, this iteration does not modify
`~/git/soloud`, does not create a new fork commit, and does not refresh
`vendor/soloud/`.

## Follow-Up Work

The remaining Vita work is Play integration, not a SoLoud fork fix. See
`docs/vita-backend-eval.md` for the full compile/link evidence and detailed
integration checklist.

- Enable `WITH_VITA_HOMEBREW` under `playPlatformVita` in
  `src/play/private/soloud_sources.nim`.
- Compile `backend/vita_homebrew/soloud_vita_homebrew.cpp` for Vita builds.
- Stop compiling `backend/nosound` and `backend/null` for Vita once the real
  backend is enabled.
- Add `-lpthread` to the grouped VitaSDK runtime libraries in `nim_vita.cfg`.
- Add a Vita link smoke check that initializes `SOLOUD_VITA_HOMEBREW`.
- Preserve the backend's current 44100 Hz stereo constraints when exposing Vita
  init options.

If a later hardware or example-build pass exposes a Vita backend defect, that
fix should land in `git@github.com:birbparty/soloud.git` first and then be
re-vendored into `play`.
