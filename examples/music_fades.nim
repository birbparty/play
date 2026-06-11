import std/[os, strutils]

import play
import common/assets

type
  MusicFadeConfig* = object
    options*: InitOptions
    holdMs*: int
    verbose*: bool

  MusicFadeResult* = object
    ok*: bool
    musicLoaded*: bool
    previewPlayed*: bool
    fadeInPlayed*: bool
    loopEnabled*: bool
    fadeOutScheduled*: bool

proc defaultMusicFadeConfig*(): MusicFadeConfig =
  MusicFadeConfig(
    options: initOptions(backend = nullBackend),
    holdMs: 25,
    verbose: false
  )

proc log(config: MusicFadeConfig, message: string) =
  if config.verbose:
    echo message

proc logFailure(config: MusicFadeConfig, label: string, result: PlayResult) =
  if config.verbose and not result.ok:
    echo label, ": ", result.error.message

proc runMusicFadeDemo*(config = defaultMusicFadeConfig()): MusicFadeResult =
  let initResult = init(config.options)
  if not initResult.ok:
    logFailure(config, "init", initResult)
    return

  var
    music = MusicResult()
    previewHandle = noHandle
    fadeHandle = noHandle

  try:
    music = loadExampleMusic(longThemeMusic)
    if not music.ok:
      logFailure(config, "load music", PlayResult(ok: false, error: music.error))
      return

    result.musicLoaded = true

    log(config, "starting streamed OGG preview")
    previewHandle = playMusic(music.music)
    result.previewPlayed = previewHandle.isValid
    if result.previewPlayed:
      discard setVolume(previewHandle, 0.35'f32)
      if config.holdMs > 0:
        sleep(config.holdMs)
      discard stop(previewHandle)

    log(config, "fading in streamed OGG music")
    fadeHandle = fadeInMusic(music.music, 0.2, 0.8'f32)
    result.fadeInPlayed = fadeHandle.isValid
    if result.fadeInPlayed:
      let loopResult = setLooping(fadeHandle, true)
      logFailure(config, "loop music", loopResult)
      result.loopEnabled = loopResult.ok

      if config.holdMs > 0:
        sleep(config.holdMs)

      let fadeOutResult = fadeOutMusic(fadeHandle, 0.2)
      logFailure(config, "fade out music", fadeOutResult)
      result.fadeOutScheduled = fadeOutResult.ok

      if config.holdMs > 0:
        sleep(config.holdMs)

    result.ok =
      result.musicLoaded and
      result.previewPlayed and
      result.fadeInPlayed and
      result.loopEnabled and
      result.fadeOutScheduled
  finally:
    if previewHandle != noHandle:
      discard stop(previewHandle)
    if fadeHandle != noHandle:
      discard stop(fadeHandle)
    if music.ok:
      music.music.dispose()
    shutdown()

proc configFromArgs*(args: seq[string]): MusicFadeConfig =
  result = defaultMusicFadeConfig()
  result.verbose = true
  for arg in args:
    case arg.normalize
    of "--audio":
      result.options = initOptions()
      result.holdMs = 500
    of "--nosound":
      result.options = initOptions(backend = noSoundBackend)
    of "--quiet":
      result.verbose = false
    else:
      discard

when isMainModule:
  let demo = runMusicFadeDemo(configFromArgs(commandLineParams()))
  if not demo.ok:
    quit 1
