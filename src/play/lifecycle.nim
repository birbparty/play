## Nim-first process lifecycle API.

import play/backends
import play/errors
import play/private/global_engine
import play/private/lifecycle as engine_lifecycle

export errors
export Backend, InitFlag, InitFlags, InitOptions
export defaultBackend, noSoundBackend, nullBackend
export `==`
export initOptions

type
  LifecycleState* = enum
    lifecycleStopped
    lifecycleRunning

proc init*(options = initOptions()): PlayResult =
  let engine = ensureEngine()

  result = engine.init(options)
  if not result.ok and not engine.isInitialized:
    clearEngine()

proc shutdown*() =
  let engine = currentEngine()
  if engine == nil:
    return

  clearEngine()

proc lifecycleState*(): LifecycleState =
  let engine = currentEngine()
  if engine != nil and engine.isInitialized:
    lifecycleRunning
  else:
    lifecycleStopped

proc activeBackend*(): Backend =
  let engine = currentEngine()
  if engine == nil:
    return defaultBackend

  engine.activeBackend()

proc withPlay*(options: InitOptions, body: proc ()) =
  let wasRunning = lifecycleState() == lifecycleRunning
  let started = init(options)
  started.raiseIfFailed()
  try:
    body()
  finally:
    if not wasRunning:
      shutdown()
