## Safe ownership and init/shutdown ordering for the raw SoLoud engine handle.

import play/backends
import play/bindings/soloud_raw as raw

type
  Engine* = ref object
    handle: raw.Soloud
    initialized: bool

  InitError* = object
    code*: cint
    message*: string

  InitResult* = object
    ok*: bool
    error*: InitError

proc failedInit(engine: Engine, code: cint): InitResult =
  var message = "SoLoud init failed"
  if engine != nil and engine.handle != nil:
    let rawMessage = raw.Soloud_getErrorString(engine.handle, code)
    if rawMessage != nil:
      message = $rawMessage

  InitResult(ok: false, error: InitError(code: code, message: message))

proc ensureHandle(engine: Engine): bool =
  if engine == nil:
    return false

  if engine.handle == nil:
    engine.handle = raw.Soloud_create()

  engine.handle != nil

proc newEngine*(): Engine =
  result = Engine()
  discard result.ensureHandle()

proc isInitialized*(engine: Engine): bool =
  engine != nil and engine.initialized

proc init*(engine: Engine, options = initOptions()): InitResult =
  if engine == nil or not engine.ensureHandle():
    return InitResult(
      ok: false,
      error: InitError(code: -1, message: "SoLoud engine allocation failed")
    )

  if engine.initialized:
    return InitResult(ok: true)

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
    return engine.failedInit(code)

  engine.initialized = true
  InitResult(ok: true)

proc shutdown*(engine: Engine) =
  if engine == nil or engine.handle == nil or not engine.initialized:
    return

  raw.Soloud_stopAll(engine.handle)
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
