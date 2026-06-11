## Voice and music fade helpers.

import play/bindings/soloud_raw as raw
import play/errors
import play/private/assets as privateAssets
import play/private/lifecycle
import play/private/types
import play/types

export types

proc invalidEngine(): PlayResult =
  failure(invalidHandleError("play engine is not initialized"))

proc invalidVoice(): PlayResult =
  failure(invalidHandleError("voice handle is no longer valid"))

proc fadeVolume*(engine: Engine, handle: Handle, target: float32, seconds: float64): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()
  if not handle.isValid or raw.Soloud_isValidVoiceHandle(soloud, handle.rawVoiceHandle) == 0:
    return invalidVoice()

  raw.Soloud_fadeVolume(soloud, handle.rawVoiceHandle, cfloat(target), cdouble(seconds))
  success()

proc fadeInMusic*(engine: Engine, music: Music, seconds: float64, target = 1.0'f32): Handle =
  let rawBus = engine.rawBus(musicBus)
  let source = music.audioSource()
  if rawBus == nil or source == nil:
    return noHandle

  let rawHandle = raw.Bus_playEx(rawBus, source, 0.0'f32, 0.0'f32, 0)
  result = handleFromRaw(rawHandle)
  if result.isValid:
    discard engine.fadeVolume(result, target, seconds)

proc fadeOutMusic*(engine: Engine, handle: Handle, seconds: float64): PlayResult =
  result = engine.fadeVolume(handle, 0.0'f32, seconds)
  if not result.ok:
    return

  raw.Soloud_scheduleStop(engine.rawHandle(), handle.rawVoiceHandle, cdouble(seconds))
