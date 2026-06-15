## Safe stream position and seek operations for explicit engine wrappers.
##
## Declares Soloud_getStreamPosition and Soloud_seek directly here rather than
## through soloud_raw.nim to work around a Nim 2.2 alias-resolution limitation
## where new importc procs added to an already-compiled module via an alias
## are marked "unknown" at call sites. Declaring them at the use site avoids
## this without forking the bindings file.

{.warning[UnusedImport]: off.}
import play/soloud_compile
{.warning[UnusedImport]: on.}

import play/bindings/soloud_raw as raw
import play/errors
import play/private/lifecycle
import play/private/types

proc Soloud_getStreamPosition(s: raw.Soloud, vh: raw.VoiceHandle): cdouble
  {.importc: "Soloud_getStreamPosition", cdecl.}

proc Soloud_seek(s: raw.Soloud, vh: raw.VoiceHandle, sec: cdouble): raw.SoloudResult
  {.importc: "Soloud_seek", cdecl.}

proc streamTime*(engine: Engine, handle: Handle): float64 =
  if engine == nil:
    return 0.0
  let soloud = engine.rawHandle()
  if soloud == nil or not handle.isValid:
    return 0.0
  float64(raw.Soloud_getStreamTime(soloud, handle.rawVoiceHandle))

proc streamPosition*(engine: Engine, handle: Handle): float64 =
  if engine == nil:
    return 0.0
  let soloud = engine.rawHandle()
  if soloud == nil or not handle.isValid:
    return 0.0
  float64(Soloud_getStreamPosition(soloud, handle.rawVoiceHandle))

proc seek*(engine: Engine, handle: Handle, seconds: float64): PlayResult =
  if engine == nil:
    return failure(invalidHandleError("play engine is not initialized"))
  let soloud = engine.rawHandle()
  if soloud == nil:
    return failure(invalidHandleError("play engine is not initialized"))
  if not handle.isValid:
    return failure(invalidHandleError("voice handle is no longer valid"))
  let code = Soloud_seek(soloud, handle.rawVoiceHandle, cdouble(seconds))
  if code != 0:
    return failure(unsupportedBackendError("seek failed (code " & $code & "); WavStream sources do not support seek", code))
  success()
