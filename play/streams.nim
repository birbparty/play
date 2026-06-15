## Per-voice stream position and seek API.

import play/errors
import play/private/global_engine
import play/private/streams as privstreams
import play/types

export types

proc streamTime*(handle: Handle): float64 =
  ## Seconds elapsed since the voice began playing (pause-gated, not loop-reset).
  ## Returns 0.0 if handle is invalid or engine not initialized.
  privstreams.streamTime(currentEngine(), handle)

proc streamPosition*(handle: Handle): float64 =
  ## Decoder read position in seconds. At playSpeed=1.0 equivalent to streamTime.
  ## Resets toward 0 on loop — use as the primary position signal for music sync.
  ## Returns 0.0 if handle is invalid or engine not initialized.
  privstreams.streamPosition(currentEngine(), handle)

proc seek*(handle: Handle, seconds: float64): PlayResult =
  ## Seek the voice to `seconds` from the start of the stream.
  ## WavStream (streamed sources) returns unsupportedBackend — only supported for
  ## non-streamed (fully-loaded) sources.
  let engine = currentEngine()
  if engine == nil:
    return failure(invalidHandleError("play engine is not initialized"))
  privstreams.seek(engine, handle, seconds)
