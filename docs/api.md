# play Phase-1 Public API

Game code imports the top-level module:

```nim
import play
```

Do not import `play/bindings/soloud_raw`, `play/soloud`, or `play/private/*`
from game code. Those modules are the raw SoLoud binding and internal wrapper
layers. The supported phase-1 API is re-exported by `import play`.

## Lifecycle

Initialize once before playback and call `shutdown` when audio is no longer
needed:

```nim
import play

let started = init(initOptions(backend = nullBackend))
started.raiseIfFailed()

echo lifecycleState() == lifecycleRunning
echo activeBackend() == nullBackend

shutdown()
```

`withPlay` is useful when a scope owns audio lifetime:

```nim
withPlay(initOptions(), proc () =
  discard setMasterVolume(0.8'f32)
)
```

`init` returns a `PlayResult`. It does not raise by default.
`raiseIfFailed(result)` converts failed results into `PlayException`.

## Assets

`loadSound` loads resident sound effects. `loadMusic` loads streamed music.
Both return result objects instead of raising:

```nim
let sfx = loadSound("assets/click.wav")
if not sfx.ok:
  echo sfx.error.message

let music = loadMusic("assets/theme.ogg")
if music.ok:
  discard playMusic(music.music)

if sfx.ok:
  sfx.sound.dispose()
if music.ok:
  music.music.dispose()
```

`Sound` and `Music` are opaque public asset types. Use `dispose` and
`isDisposed`; do not inspect raw SoLoud handles.

## Playback

Use `play` for resident sounds and `playMusic` for streamed music:

```nim
let soundResult = loadSound("assets/menu.wav")
if soundResult.ok:
  let handle = play(soundResult.sound)
  if handle.isValid:
    discard setVolume(handle, 0.7'f32)

let musicResult = loadMusic("assets/loop.ogg")
if musicResult.ok:
  let musicHandle = playMusic(musicResult.music)
  discard setLooping(musicHandle, true)
```

Sounds route to `defaultSoundBus`, currently `sfxBus`, unless a bus is provided:

```nim
discard play(soundResult.sound, uiBus)
```

## Handles

Playback returns a `Handle`. Public handle operations are safe on invalid or
dead handles and report failures through `PlayResult`:

```nim
let handle = play(soundResult.sound)

if handle.isValid:
  discard pause(handle)
  discard resume(handle)
  discard setLooping(handle, false)
  discard setVolume(handle, 0.5'f32)
  discard stop(handle)
```

`isValid(handle)` checks liveness against the current `play` engine. A handle
can become invalid after `stop`, voice stealing, or `shutdown`.

## Fixed Buses

Phase 1 exposes three fixed buses:

- `musicBus`
- `sfxBus`
- `uiBus`

`defaultSoundBus` is `sfxBus`. Use bus volume helpers for common mix controls:

```nim
discard setMasterVolume(0.9'f32)
discard setMusicVolume(0.6'f32)
discard setSfxVolume(1.0'f32)
discard setUiVolume(0.8'f32)
```

Custom bus creation is not part of phase 1.

## Fades

Fades operate on public handles. `fadeInMusic` starts music at zero volume and
fades it to the target. `fadeOutMusic` fades to silence and schedules a stop
after the fade:

```nim
let musicResult = loadMusic("assets/theme.ogg")
if musicResult.ok:
  let handle = fadeInMusic(musicResult.music, 1.5, 0.75'f32)
  discard fadeVolume(handle, 0.4'f32, 0.25)
  discard fadeOutMusic(handle, 1.0)
```

Fade timers advance while SoLoud mixes audio. In tests or manual headless pump
loops using NULLDRIVER/NOSOUND, allow time to pass and pump/mix before checking
the final volume or stop state.

## Errors And Results

Most mutating APIs return `PlayResult`:

```nim
let result = setSfxVolume(0.5'f32)
if not result.ok:
  case result.error.kind
  of invalidHandle:
    echo "audio is not initialized or the target handle is dead"
  of initFailed, unsupportedBackend, loadFailed, invalidAsset, allocationFailed:
    echo result.error.message
```

Use `raiseIfFailed` if exceptions fit the caller:

```nim
init(initOptions()).raiseIfFailed()
setMasterVolume(0.8'f32).raiseIfFailed()
```

Error helpers such as `initError`, `loadError`, `invalidAssetError`, and
`invalidHandleError` are public for tests and integrations that need to build
or translate `PlayError` values.

## Platform Defines

`platformDefaultBackend()` chooses the backend for the target:

- desktop: SoLoud `AUTO`
- `-d:playPlatform3ds`: 3DS `ctru_ndsp`
- `-d:playPlatformVita`: Vita homebrew backend

Common init options:

```nim
let options = initOptions(
  backend = platformDefaultBackend(),
  flags = {clipRoundoff},
  sampleRate = 44100'u32,
  bufferSize = 2048'u32,
  channels = 2'u32
)
```

3DS and Vita builds require their homebrew SDK/toolchain configuration. This
repository does not redistribute proprietary SDK, firmware, or console vendor
material.

## Voice Limits

Phase-1 wrapper internals apply a platform default active voice limit:

- desktop: 16
- Vita: 12
- 3DS: 10

The fixed bus system reserves three voices. Game-facing custom voice-limit
configuration is not part of the phase-1 top-level `play` API.
