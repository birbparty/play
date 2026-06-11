# play

Nim audio library for games built on the birbparty fork of SoLoud.

`play` exposes a Nim-first game API from one import:

```nim
import play
```

Game code should not import `play/bindings/soloud_raw`, `play/soloud`, or
`play/private/*`. Those modules are implementation and wrapper layers for
`play` itself.

## Phase-1 API

Phase 1 covers:

- lifecycle: `init`, `shutdown`, `withPlay`, `lifecycleState`, `activeBackend`
- backend options: `initOptions`, `defaultBackend`, `noSoundBackend`,
  `nullBackend`, `clipRoundoff`, `enableVisualization`, `leftHanded3d`,
  `noFpuRegisterChange`
- assets: `loadSound`, `loadMusic`, `dispose`, `isDisposed`
- playback: `play`, `playMusic`
- handles: `isValid`, `pause`, `resume`, `stop`, `setLooping`, `setVolume`
- fixed buses: `musicBus`, `sfxBus`, `uiBus`, `defaultSoundBus`,
  `setMasterVolume`, `setMusicVolume`, `setSfxVolume`, `setUiVolume`
- fades: `fadeVolume`, `fadeInMusic`, `fadeOutMusic`
- result/error values: `PlayResult`, `PlayError`, `PlayException`

See [`docs/api.md`](docs/api.md) for examples and platform notes. A compact
end-to-end example lives in [`examples/phase1_public_api.nim`](examples/phase1_public_api.nim).

## Build And Verification

Host verification:

```sh
nimble test -y
nimble testTap -y
nimble testJunit -y
```

Desktop examples:

```sh
bash scripts/build_desktop_examples.sh --smoke
```

Console example packages:

- Nintendo 3DS: [`docs/3ds-build.md`](docs/3ds-build.md)
- PS Vita: [`docs/vita-build.md`](docs/vita-build.md)

Real console audio output is tracked separately as a human hardware gate:

- Nintendo 3DS: [`docs/3ds-hardware-verification.md`](docs/3ds-hardware-verification.md)
- PS Vita: [`docs/vita-hardware-verification.md`](docs/vita-hardware-verification.md)

Release readiness is summarized in
[`docs/release-checklist.md`](docs/release-checklist.md).

## Consumption

See [`docs/consumption.md`](docs/consumption.md) for Nimble URL pins, local path
dependencies, and console-style `--path` source injection.

## Licensing

`play` is distributed under the Zlib license. SoLoud is also Zlib-licensed; its
vendored license and notices must be preserved when `vendor/soloud/` is added.

Project code, generated assets, and test fixtures must stay under permissive
terms that allow commercial use. Proprietary SDK files, firmware, and console
vendor material are not redistributed by this repository. See
[`docs/licensing.md`](docs/licensing.md) for the full third-party asset policy.
