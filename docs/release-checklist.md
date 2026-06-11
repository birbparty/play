# Phase-1 Release Checklist

This checklist records the current phase-1 acceptance evidence for `play`.
Phase 1 is complete for agent-verifiable build, test, packaging, and
documentation work. Real console audio output remains a human hardware gate.

## Host Tests

Run the full host gate from the repository root:

```sh
nimble test -y
nimble testTap -y
nimble testJunit -y
test -s tests/results/test_all.xml
test -s tests/results/test_host_stress_arc.xml
test -s tests/results/test_host_stress_arc.tap
```

Coverage includes:

- consumer install smoke test through Nimble
- console-style `--path` consumer compile checks
- desktop example builds and headless smoke runs
- raw binding and backend compile checks
- public API, wrapper, fixture, realtime-boundary, and host stress bddy suites
- ORC/default test aggregation and ARC host stress execution
- TAP and JUnit report generation

## Desktop Examples

Desktop examples are agent-verifiable on the host:

```sh
bash scripts/build_desktop_examples.sh --smoke
```

The GitHub Actions desktop matrix runs the same smoke path on:

- `ubuntu-latest`
- `macos-latest`
- `windows-latest`

The matrix also installs Nim 2.2.10, runs the Nimble consumer check, runs the
path-injected consumer check, runs `nimble testJunit -y`, and uploads
`tests/results/*.xml`.

## Console Cross-Compile Artifacts

Nintendo 3DS:

```sh
DEVKITPRO=/opt/devkitpro scripts/build_3ds_examples.sh --out-dir build/3ds
```

Expected artifacts:

- `build/3ds/phase1_public_api.3dsx`
- `build/3ds/bus_volume_demo.3dsx`
- `build/3ds/music_fades.3dsx`
- `build/3ds/sfx_keypress.3dsx`
- `build/3ds/sdroot/tests/fixtures/generated/`

PS Vita:

```sh
scripts/build_vita_examples.sh --out-dir build/vita
```

Expected artifacts:

- `build/vita/phase1_public_api.vpk`
- `build/vita/bus_volume_demo.vpk`
- `build/vita/music_fades.vpk`
- `build/vita/sfx_keypress.vpk`

The CI workflow cross-compiles both console targets and uploads the generated
packages/artifacts. Console build details live in `docs/3ds-build.md` and
`docs/vita-build.md`.

## Hardware Gates

Hardware output cannot be proven by host CI. The gates are explicitly recorded
as blocked until a human runs the artifacts:

- `play-xu8`: Nintendo 3DS hardware run. Requires `sdmc:/3ds/dspfirm.cdc` and
  `build/3ds/sdroot/` copied to the SD card root. Checklist:
  `docs/3ds-hardware-verification.md`.
- `play-2fv`: PS Vita hardware or emulator run. Checklist:
  `docs/vita-hardware-verification.md`.

To close either gate, record the hardware/emulator setup, exact build command,
artifacts launched, observed audio/output behavior, and any crash/error text.
If a hardware run fails, open follow-up Beads for each distinct failure and link
them from the relevant hardware gate.

## Consumption Modes

Supported phase-1 consumption paths are documented in `docs/consumption.md`:

- Nimble URL pin:
  `requires "https://github.com/birbparty/play#<commit-sha>"`
- local path dependency:
  `requires "file:///absolute/path/to/play"`
- console-style source injection:
  `nim c --path:/absolute/path/to/play/src src/my_game.nim`

Game code imports only:

```nim
import play
```

Raw bindings, `play/soloud`, and `play/private/*` remain implementation
details.

## CI Gate

The GitHub Actions workflow in `.github/workflows/ci.yml` contains:

- desktop Linux/macOS/Windows matrix with JUnit artifacts
- Nintendo 3DS cross-compile artifact job
- PS Vita cross-compile package job

Before tagging or cutting a release, confirm the latest `main` workflow run is
green and that the hardware gates are either completed or explicitly documented
as blocked.
