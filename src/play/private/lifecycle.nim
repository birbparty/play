## Safe ownership and init/shutdown ordering for the raw SoLoud engine handle.

import play/backends
import play/bindings/soloud_raw as raw
import play/errors
import play/types as publicTypes

type
  Engine* = ref object
    handle: raw.Soloud
    initialized: bool
    musicBus: raw.Bus
    sfxBus: raw.Bus
    uiBus: raw.Bus

proc destroyBuses(engine: Engine) =
  if engine == nil:
    return

  if engine.musicBus != nil:
    raw.Bus_destroy(engine.musicBus)
    engine.musicBus = nil
  if engine.sfxBus != nil:
    raw.Bus_destroy(engine.sfxBus)
    engine.sfxBus = nil
  if engine.uiBus != nil:
    raw.Bus_destroy(engine.uiBus)
    engine.uiBus = nil

proc resetHandle(engine: Engine) =
  if engine == nil or engine.handle == nil:
    return

  engine.destroyBuses()
  raw.Soloud_destroy(engine.handle)
  engine.handle = nil
  engine.initialized = false

proc failedInit(engine: Engine, options: InitOptions, code: cint): PlayResult =
  var message = "SoLoud init failed"
  if engine != nil and engine.handle != nil:
    let rawMessage = raw.Soloud_getErrorString(engine.handle, code)
    if rawMessage != nil:
      message = $rawMessage

  let kind =
    if not options.backend.isKnownBackend:
      unsupportedBackend
    else:
      initFailed
  engine.resetHandle()
  failure(playError(kind, message, code))

proc ensureHandle(engine: Engine): bool =
  if engine == nil:
    return false

  if engine.handle == nil:
    engine.handle = raw.Soloud_create()

  engine.handle != nil

proc newEngine*(): Engine =
  result = Engine()
  discard result.ensureHandle()

proc initBus(engine: Engine, bus: var raw.Bus): bool =
  bus = raw.Bus_create()
  if bus == nil:
    return false

  raw.Soloud_play(engine.handle, raw.AudioSource(bus)) != 0'u32

proc initBuses(engine: Engine): bool =
  engine.initBus(engine.musicBus) and
    engine.initBus(engine.sfxBus) and
    engine.initBus(engine.uiBus)

proc isInitialized*(engine: Engine): bool =
  engine != nil and engine.initialized

proc init*(engine: Engine, options = initOptions()): PlayResult =
  if engine == nil or not engine.ensureHandle():
    return failure(allocationError("SoLoud engine allocation failed"))

  if engine.initialized:
    return success()

  let args = rawInitArgs(options)
  let code = raw.Soloud_initEx(
    engine.handle,
    args.flags,
    args.backend,
    args.sampleRate,
    args.bufferSize,
    args.channels
  )
  if code != 0:
    return engine.failedInit(options, code)

  if not engine.initBuses():
    engine.destroyBuses()
    raw.Soloud_deinit(engine.handle)
    engine.resetHandle()
    return failure(allocationError("SoLoud fixed bus allocation failed"))

  engine.initialized = true
  success()

proc shutdown*(engine: Engine) =
  if engine == nil or engine.handle == nil or not engine.initialized:
    return

  raw.Soloud_stopAll(engine.handle)
  engine.destroyBuses()
  raw.Soloud_deinit(engine.handle)
  engine.initialized = false

proc destroy*(engine: Engine) =
  if engine == nil or engine.handle == nil:
    return

  engine.shutdown()
  raw.Soloud_destroy(engine.handle)
  engine.handle = nil

proc activeBackend*(engine: Engine): Backend =
  if engine == nil or engine.handle == nil or not engine.initialized:
    return defaultBackend

  Backend(raw.Soloud_getBackendId(engine.handle))

proc rawHandle*(engine: Engine): raw.Soloud =
  if engine == nil or engine.handle == nil or not engine.initialized:
    return nil

  engine.handle

proc rawBus*(engine: Engine, bus: publicTypes.Bus): raw.Bus =
  if engine == nil or engine.handle == nil or not engine.initialized or not bus.isValid:
    return nil

  if bus == publicTypes.musicBus:
    engine.musicBus
  elif bus == publicTypes.sfxBus:
    engine.sfxBus
  elif bus == publicTypes.uiBus:
    engine.uiBus
  else:
    nil
