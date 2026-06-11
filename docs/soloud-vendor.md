# SoLoud Vendor Snapshot

`vendor/soloud/` is a source snapshot of the birbparty SoLoud fork used by
`play` phase 1.

## Snapshot

- Source checkout: `~/git/soloud`
- Remote: `git@github.com:birbparty/soloud.git`
- Branch copied: `feat/3ds-support`
- Commit copied: `e82fd32c1f62183922f08c14c814a02b58db1873`
- Copy method: `rsync -a --delete --exclude='.git/' ~/git/soloud/ vendor/soloud/`

The vendored file count matches the fork's tracked file count at the copied
commit. The fork's Git metadata is not vendored.

For future re-vendors, prefer a tracked-file-only copy so ignored build outputs
from the fork cannot enter the snapshot. One repeatable approach is:

```sh
rm -rf vendor/soloud
mkdir -p vendor/soloud
git -C ~/git/soloud archive --format=tar HEAD | tar -x -C vendor/soloud
```

Verify the copied file set before committing:

```sh
git -C ~/git/soloud ls-files | sort > /tmp/soloud-source-files.txt
git ls-files vendor/soloud | sed 's#^vendor/soloud/##' | sort > /tmp/soloud-vendor-files.txt
comm -23 /tmp/soloud-source-files.txt /tmp/soloud-vendor-files.txt
comm -13 /tmp/soloud-source-files.txt /tmp/soloud-vendor-files.txt
```

Both `comm` commands should print nothing.

## License

SoLoud proper is licensed under the zlib/libpng license. Preserve
`vendor/soloud/LICENSE` and upstream notices when updating the snapshot.

SoLoud also includes third-party source with permissive licenses; consult the
vendored license file and SoLoud documentation before enabling optional
components. Phase 1 should avoid optional sources that need unavailable external
libraries unless a later bead explicitly adds and documents them.

Do not compile every `vendor/soloud/src/**/*.cpp` file by glob. The phase-1
compile closure and optional-source caveats are tracked in
`docs/soloud-vendor-audit.md`.

## Patch Policy

Do not edit `vendor/soloud/` directly as the source of truth. Backend fixes,
thread and mutex portability work, C API enum changes, generated C API changes,
and Vita or 3DS patches must land in `git@github.com:birbparty/soloud.git`
first. After those fork commits exist, re-vendor a fresh snapshot and update
this document with the new commit SHA.

Generated C API files such as `include/soloud_c.h` and
`src/c_api/soloud_c.cpp` should be regenerated in the fork rather than patched
only in `play`.

## Submodules

The copied fork preserves the upstream `.gitmodules` entry for `ext/libmodplug`
as snapshot metadata, but the pinned commit has no tracked gitlink and the
phase-1 snapshot does not vendor that submodule content. Do not initialize
submodules from `play` unless a later OpenMPT/libmodplug bead explicitly enables
and documents that dependency.
