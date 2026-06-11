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

The remaining Vita work after this decision was Play integration, not a SoLoud
fork fix. That integration now lives in the Play build surface:

- `src/play/private/soloud_sources.nim` enables `WITH_VITA_HOMEBREW` under
  `playPlatformVita`.
- Vita builds compile `backend/vita_homebrew/soloud_vita_homebrew.cpp` instead
  of the host headless backends.
- `nim_vita.cfg` includes `-lpthread` in the grouped VitaSDK runtime libraries.
- `scripts/build_vita_examples.sh` builds and packages the examples with
  `nim c -d:vita`.

See `docs/vita-build.md` for the current example build and packaging flow.

If a later hardware or example-build pass exposes a Vita backend defect, that
fix should land in `git@github.com:birbparty/soloud.git` first and then be
re-vendored into `play`.
