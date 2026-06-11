import std/[os, strutils]

import play
import common/assets

type
  BusDemoConfig* = object
    options*: InitOptions
    holdMs*: int
    verbose*: bool

  BusDemoResult* = object
    ok*: bool
    musicPlayed*: bool
    sfxPlayed*: bool
    uiPlayed*: bool
    volumesChanged*: bool

proc defaultBusDemoConfig*(): BusDemoConfig =
  when defined(playPlatform3ds) or defined(playPlatformVita):
    let options = initOptions()
  else:
    let options = initOptions(backend = nullBackend)
  BusDemoConfig(
    options: options,
    holdMs: 25,
    verbose: false
  )

proc log(config: BusDemoConfig, message: string) =
  if config.verbose:
    echo message

proc logFailure(config: BusDemoConfig, label: string, result: PlayResult) =
  if config.verbose and not result.ok:
    echo label, ": ", result.error.message

proc applyVolume(
  config: BusDemoConfig,
  label: string,
  volume: float32,
  setter: proc (volume: float32): PlayResult
): bool =
  let volumeResult = setter(volume)
  logFailure(config, label, volumeResult)
  volumeResult.ok

proc runBusVolumeDemo*(config = defaultBusDemoConfig()): BusDemoResult =
  let initResult = init(config.options)
  if not initResult.ok:
    logFailure(config, "init", initResult)
    return

  var
    sfx = SoundResult()
    music = MusicResult()
    sfxHandle = noHandle
    uiHandle = noHandle
    musicHandle = noHandle

  try:
    result.volumesChanged =
      applyVolume(config, "master volume", 0.85'f32, setMasterVolume) and
      applyVolume(config, "music volume", 0.45'f32, setMusicVolume) and
      applyVolume(config, "sfx volume", 1.0'f32, setSfxVolume) and
      applyVolume(config, "ui volume", 0.65'f32, setUiVolume)

    sfx = loadExampleSound(clickSfx)
    if not sfx.ok:
      logFailure(config, "load sfx", PlayResult(ok: false, error: sfx.error))
      return

    music = loadExampleMusic(themeMusic)
    if not music.ok:
      logFailure(config, "load music", PlayResult(ok: false, error: music.error))
      return

    log(config, "playing streamed music on music bus")
    musicHandle = playMusic(music.music)
    result.musicPlayed = musicHandle.isValid

    log(config, "playing click sound on sfx bus")
    sfxHandle = play(sfx.sound, sfxBus)
    result.sfxPlayed = sfxHandle.isValid

    log(config, "playing click sound on ui bus")
    uiHandle = play(sfx.sound, uiBus)
    result.uiPlayed = uiHandle.isValid

    if result.musicPlayed:
      discard setLooping(musicHandle, true)
      discard setVolume(musicHandle, 0.7'f32)
    if result.sfxPlayed:
      discard setVolume(sfxHandle, 0.9'f32)
    if result.uiPlayed:
      discard setVolume(uiHandle, 0.55'f32)

    if config.holdMs > 0:
      sleep(config.holdMs)

    result.volumesChanged = result.volumesChanged and
      applyVolume(config, "master volume duck", 0.55'f32, setMasterVolume) and
      applyVolume(config, "music volume raise", 0.8'f32, setMusicVolume) and
      applyVolume(config, "sfx volume duck", 0.35'f32, setSfxVolume) and
      applyVolume(config, "ui volume raise", 1.0'f32, setUiVolume)

    if config.holdMs > 0:
      sleep(config.holdMs)

    result.ok =
      result.volumesChanged and
      result.musicPlayed and
      result.sfxPlayed and
      result.uiPlayed
  finally:
    if sfxHandle != noHandle:
      discard stop(sfxHandle)
    if uiHandle != noHandle:
      discard stop(uiHandle)
    if musicHandle != noHandle:
      discard stop(musicHandle)
    if sfx.ok:
      sfx.sound.dispose()
    if music.ok:
      music.music.dispose()
    shutdown()

proc configFromArgs*(args: seq[string]): BusDemoConfig =
  result = defaultBusDemoConfig()
  result.verbose = true
  for arg in args:
    case arg.normalize
    of "--audio":
      result.options = initOptions()
      result.holdMs = 250
    of "--nosound":
      result.options = initOptions(backend = noSoundBackend)
    of "--quiet":
      result.verbose = false
    else:
      discard

when isMainModule:
  let demo = runBusVolumeDemo(configFromArgs(commandLineParams()))
  if not demo.ok:
    quit 1
