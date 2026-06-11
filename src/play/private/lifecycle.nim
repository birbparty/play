## Safe ownership and init/shutdown ordering for the raw SoLoud engine handle.

import play/backends
import play/bindings/soloud_raw as raw
import play/errors
import play/types as publicTypes
import play/voices

type
  Engine* = ref object
    handle: raw.Soloud
    initialized: bool
    musicBus: raw.Bus
    musicBusHandle: raw.VoiceHandle
    sfxBus: raw.Bus
    sfxBusHandle: raw.VoiceHandle
    uiBus: raw.Bus
    uiBusHandle: raw.VoiceHandle
    voiceOptions: VoiceOptions

proc destroyBuses(engine: Engine) =
  if engine == nil:
    return

  engine.musicBusHandle = 0'u32
  engine.sfxBusHandle = 0'u32
  engine.uiBusHandle = 0'u32

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
  result.voiceOptions = voiceOptions()
  discard result.ensureHandle()

proc setVoiceOptions*(engine: Engine, options: VoiceOptions): PlayResult =
  if engine == nil:
    return failure(invalidHandleError("play engine is not initialized"))
  if engine.initialized:
    return failure(initError("voice options must be set before engine initialization", 0))
  if options.maxActiveVoices == 0'u32:
    return failure(initError("max active voices must be greater than zero", 0))

  engine.voiceOptions = options
  success()

proc activeVoiceLimit*(engine: Engine): cuint =
  if engine == nil:
    return 0'u32

  if engine.initialized and engine.handle != nil:
    return raw.Soloud_getMaxActiveVoiceCount(engine.handle)

  engine.voiceOptions.maxActiveVoices

proc activeVoiceCount*(engine: Engine): cuint =
  if engine == nil or engine.handle == nil:
    return 0'u32

  raw.Soloud_getActiveVoiceCount(engine.handle)

proc initBus(engine: Engine, bus: var raw.Bus, busHandle: var raw.VoiceHandle): bool =
  bus = raw.Bus_create()
  if bus == nil:
    return false

  busHandle = raw.Soloud_play(engine.handle, raw.AudioSource(bus))
  if busHandle == 0'u32:
    raw.Bus_destroy(bus)
    bus = nil
    return false

  true

proc initBuses(engine: Engine): bool =
  engine.initBus(engine.musicBus, engine.musicBusHandle) and
    engine.initBus(engine.sfxBus, engine.sfxBusHandle) and
    engine.initBus(engine.uiBus, engine.uiBusHandle)

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

  let voiceCode = raw.Soloud_setMaxActiveVoiceCount(engine.handle, engine.voiceOptions.maxActiveVoices)
  if voiceCode != 0:
    raw.Soloud_deinit(engine.handle)
    engine.resetHandle()
    return failure(initError("Failed to configure SoLoud active voice limit", voiceCode))

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

proc rawBusHandle*(engine: Engine, bus: publicTypes.Bus): raw.VoiceHandle =
  if engine == nil or engine.handle == nil or not engine.initialized or not bus.isValid:
    return 0'u32

  if bus == publicTypes.musicBus:
    engine.musicBusHandle
  elif bus == publicTypes.sfxBus:
    engine.sfxBusHandle
  elif bus == publicTypes.uiBus:
    engine.uiBusHandle
  else:
    0'u32
