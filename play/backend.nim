## Backend info and audio pump API.

import play/private/global_engine
import play/private/lifecycle
import play/bindings/soloud_raw as raw

proc backendSamplerate*(): int =
  ## Returns the audio backend's sample rate in Hz, or 0 if not initialized.
  let engine = currentEngine()
  if engine == nil:
    return 0
  let soloud = engine.rawHandle()
  if soloud == nil:
    return 0
  int(raw.Soloud_getBackendSamplerate(soloud))

proc backendBufferSize*(): int =
  ## Returns the audio backend's buffer size in samples, or 0 if not initialized.
  let engine = currentEngine()
  if engine == nil:
    return 0
  let soloud = engine.rawHandle()
  if soloud == nil:
    return 0
  int(raw.Soloud_getBackendBufferSize(soloud))

proc outputLatency*(): float64 =
  ## Estimated audio pipeline output latency in seconds.
  ## Derived as bufferSize / sampleRate. Returns 0.0 when sampleRate == 0.
  let sr = backendSamplerate()
  if sr == 0:
    return 0.0
  float64(backendBufferSize()) / float64(sr)

proc pumpAudio*(samples: int = 0) =
  ## Drive the audio mix on a null/noSound backend (for testing).
  ## Advances SoLoud's internal clocks by mixing `samples` frames.
  ## A no-op if the engine is not initialized.
  let engine = currentEngine()
  if engine == nil:
    return
  let soloud = engine.rawHandle()
  if soloud == nil:
    return
  let count = if samples <= 0: 1024 else: samples
  var buf = newSeq[int16](count * 2)
  raw.Soloud_mixSigned16(soloud, addr buf[0], cuint(count))
