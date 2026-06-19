## Backend info and audio pump API.

import play/backends
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

proc backendString*(): string =
  ## Name of the resolved audio backend as reported by SoLoud — e.g.
  ## "CoreAudio", "MiniAudio", "NoSound", "null driver". Returns "" when the
  ## engine is not initialized. Useful for logging what `init(AUTO)` actually
  ## selected.
  let engine = currentEngine()
  if engine == nil:
    return ""
  let soloud = engine.rawHandle()
  if soloud == nil:
    return ""
  let s = raw.Soloud_getBackendString(soloud)
  if s == nil: "" else: $s

proc isAudibleBackend*(): bool =
  ## True when the resolved backend can actually produce sound — i.e. it is NOT
  ## the silent NoSound fallback or the NULL driver. Returns false when the
  ## engine is not initialized.
  ##
  ## `init(initOptions()).ok == true` does NOT imply audible output: on desktop
  ## the default backend is SoLoud AUTO, which walks its compiled backend chain
  ## and, if every real backend fails to open a device, lands on NoSound — a
  ## fully-functional but silent backend that still reports success and a valid
  ## sample rate. Call this after `init` to assert you actually got a device.
  ##
  ## Implemented as a denylist (not an allowlist of CoreAudio/MiniAudio) so the
  ## audible Vita/3DS homebrew backends are never misreported as silent.
  let engine = currentEngine()
  if engine == nil:
    return false
  if engine.rawHandle() == nil:
    # Allocated but not initialized — no device, so not audible.
    return false
  let b = engine.activeBackend()
  b != noSoundBackend and b != nullBackend

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
