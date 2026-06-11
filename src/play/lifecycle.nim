## Nim-first process lifecycle API.

import play/backends
import play/errors
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

var engine: Engine

proc init*(options = initOptions()): PlayResult =
  if engine == nil:
    engine = newEngine()

  result = engine.init(options)
  if not result.ok and not engine.isInitialized:
    engine.destroy()
    engine = nil

proc shutdown*() =
  if engine == nil:
    return

  engine.destroy()
  engine = nil

proc lifecycleState*(): LifecycleState =
  if engine != nil and engine.isInitialized:
    lifecycleRunning
  else:
    lifecycleStopped

proc activeBackend*(): Backend =
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
