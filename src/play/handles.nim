## Safe voice handle operations.

import play/bindings/soloud_raw as raw
import play/errors
import play/private/assets as privateAssets
import play/private/lifecycle
import play/private/types
import play/types

export privateAssets except audioSource
export types

proc invalidEngine(): PlayResult =
  failure(invalidHandleError("play engine is not initialized"))

proc invalidVoice(): PlayResult =
  failure(invalidHandleError("voice handle is no longer valid"))

proc isValid*(engine: Engine, handle: Handle): bool =
  let soloud = engine.rawHandle()
  soloud != nil and handle.isValid and
    raw.Soloud_isValidVoiceHandle(soloud, handle.rawVoiceHandle) != 0

proc playSound*(engine: Engine, sound: Sound): Handle =
  let soloud = engine.rawHandle()
  let source = sound.audioSource()
  if soloud == nil or source == nil:
    return noHandle

  handleFromRaw(raw.Soloud_play(soloud, source))

proc playMusic*(engine: Engine, music: Music): Handle =
  let soloud = engine.rawHandle()
  let source = music.audioSource()
  if soloud == nil or source == nil:
    return noHandle

  handleFromRaw(raw.Soloud_play(soloud, source))

proc pause*(engine: Engine, handle: Handle): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()
  if not engine.isValid(handle):
    return invalidVoice()

  raw.Soloud_setPause(soloud, handle.rawVoiceHandle, 1)
  success()

proc resume*(engine: Engine, handle: Handle): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()
  if not engine.isValid(handle):
    return invalidVoice()

  raw.Soloud_setPause(soloud, handle.rawVoiceHandle, 0)
  success()

proc stop*(engine: Engine, handle: Handle): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()
  if not engine.isValid(handle):
    return invalidVoice()

  raw.Soloud_stop(soloud, handle.rawVoiceHandle)
  success()

proc setLooping*(engine: Engine, handle: Handle, looping: bool): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()
  if not engine.isValid(handle):
    return invalidVoice()

  raw.Soloud_setLooping(soloud, handle.rawVoiceHandle, if looping: 1 else: 0)
  success()

proc setVolume*(engine: Engine, handle: Handle, volume: float32): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()
  if not engine.isValid(handle):
    return invalidVoice()

  raw.Soloud_setVolume(soloud, handle.rawVoiceHandle, cfloat(volume))
  success()
