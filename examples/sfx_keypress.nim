import std/[os, strutils]
when not (defined(playPlatform3ds) or defined(playPlatformVita)):
  import std/terminal

import play
import common/assets
import common/input

type
  SfxKeypressConfig* = object
    options*: InitOptions
    keys*: string
    holdMs*: int
    verbose*: bool

  SfxKeypressResult* = object
    ok*: bool
    initialized*: bool
    soundLoaded*: bool
    playedCount*: int
    quitRequested*: bool

proc defaultSfxKeypressConfig*(): SfxKeypressConfig =
  when defined(playPlatform3ds) or defined(playPlatformVita):
    let options = initOptions()
  else:
    let options = initOptions(backend = nullBackend)
  SfxKeypressConfig(
    options: options,
    keys: "s",
    holdMs: 25,
    verbose: false
  )

proc log(config: SfxKeypressConfig, message: string) =
  if config.verbose:
    echo message

proc logFailure(config: SfxKeypressConfig, label: string, result: PlayResult) =
  if config.verbose and not result.ok:
    echo label, ": ", result.error.message

proc playForKey(
  key: char,
  config: SfxKeypressConfig,
  sound: Sound,
  activeHandles: var seq[Handle],
  demoResult: var SfxKeypressResult
): bool =
  case actionForKey(key)
  of playSfx:
    log(config, "playing WAV SFX")
    let handle = play(sound, sfxBus)
    if handle.isValid:
      activeHandles.add(handle)
      inc demoResult.playedCount
      if config.holdMs > 0:
        sleep(config.holdMs)
  of quitExample:
    demoResult.quitRequested = true
    return false
  else:
    discard

  true

proc runInteractiveKeys(
  config: SfxKeypressConfig,
  sound: Sound,
  activeHandles: var seq[Handle],
  demoResult: var SfxKeypressResult
) =
  when defined(playPlatform3ds) or defined(playPlatformVita):
    discard config
    discard sound
    discard activeHandles
    discard demoResult
  else:
    if config.verbose:
      echo "Press s or space for SFX, q to quit."

    while true:
      if not playForKey(getch(), config, sound, activeHandles, demoResult):
        break

proc runSfxKeypressDemo*(config = defaultSfxKeypressConfig()): SfxKeypressResult =
  let initResult = init(config.options)
  if not initResult.ok:
    logFailure(config, "init", initResult)
    return

  result.initialized = true

  var
    sound = SoundResult()
    activeHandles: seq[Handle] = @[]

  try:
    sound = loadExampleSound(clickSfx)
    if not sound.ok:
      logFailure(config, "load sfx", PlayResult(ok: false, error: sound.error))
      return

    result.soundLoaded = true

    if config.keys.len == 0:
      runInteractiveKeys(config, sound.sound, activeHandles, result)
    else:
      for key in config.keys:
        if not playForKey(key, config, sound.sound, activeHandles, result):
          break

    result.ok = result.initialized and result.soundLoaded and result.playedCount > 0
  finally:
    for handle in activeHandles:
      discard stop(handle)
    if sound.ok:
      sound.sound.dispose()
    shutdown()

proc configFromArgs*(args: seq[string]): SfxKeypressConfig =
  result = defaultSfxKeypressConfig()
  result.verbose = true
  for arg in args:
    if arg.startsWith("--keys="):
      result.keys = arg.substr("--keys=".len)
    else:
      case arg.normalize
      of "--audio":
        result.options = initOptions()
        result.holdMs = 100
        result.keys = ""
      of "--nosound":
        result.options = initOptions(backend = noSoundBackend)
      of "--quiet":
        result.verbose = false
      else:
        discard

when isMainModule:
  let demo = runSfxKeypressDemo(configFromArgs(commandLineParams()))
  if not demo.ok:
    quit 1
