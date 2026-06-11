## Fixed bus volume controls.

import play/bindings/soloud_raw as raw
import play/errors
import play/private/lifecycle
import play/types as publicTypes

export publicTypes

proc invalidEngine(): PlayResult =
  failure(invalidHandleError("play engine is not initialized"))

proc invalidBus(): PlayResult =
  failure(invalidHandleError("fixed bus is not initialized"))

proc setMasterVolume*(engine: Engine, volume: float32): PlayResult =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return invalidEngine()

  raw.Soloud_setGlobalVolume(soloud, cfloat(volume))
  success()

proc setBusVolume(engine: Engine, bus: publicTypes.Bus, volume: float32): PlayResult =
  let rawBus = engine.rawBus(bus)
  if rawBus == nil:
    return invalidBus()

  raw.Bus_setVolume(rawBus, cfloat(volume))
  success()

proc setMusicVolume*(engine: Engine, volume: float32): PlayResult =
  engine.setBusVolume(musicBus, volume)

proc setSfxVolume*(engine: Engine, volume: float32): PlayResult =
  engine.setBusVolume(sfxBus, volume)

proc setUiVolume*(engine: Engine, volume: float32): PlayResult =
  engine.setBusVolume(uiBus, volume)
