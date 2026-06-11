## Nim-first public voice handle operations.

import play/private/global_engine
import play/private/handles as engine_handles
import play/errors
import play/types

export types

proc isValid*(handle: Handle): bool =
  let engine = currentEngine()
  if engine == nil:
    return false

  engine_handles.isValid(engine, handle)

proc pause*(handle: Handle): PlayResult =
  engine_handles.pause(currentEngine(), handle)

proc resume*(handle: Handle): PlayResult =
  engine_handles.resume(currentEngine(), handle)

proc stop*(handle: Handle): PlayResult =
  engine_handles.stop(currentEngine(), handle)

proc setLooping*(handle: Handle, looping: bool): PlayResult =
  engine_handles.setLooping(currentEngine(), handle, looping)

proc setVolume*(handle: Handle, volume: float32): PlayResult =
  engine_handles.setVolume(currentEngine(), handle, volume)
