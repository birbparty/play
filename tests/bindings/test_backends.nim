import play/backends
import play/bindings/soloud_raw

static:
  doAssert rawBackendId(defaultBackend) == SOLOUD_AUTO
  doAssert rawBackendId(noSoundBackend) == SOLOUD_NOSOUND
  doAssert rawBackendId(nullBackend) == SOLOUD_NULLDRIVER
  doAssert rawBackendId(backendMax) == SOLOUD_BACKEND_MAX

  when defined(playPlatformVita):
    doAssert rawBackendId(vitaHomebrewBackend) == SOLOUD_VITA_HOMEBREW

  when defined(playPlatform3ds):
    doAssert rawBackendId(ctruNdspBackend) == SOLOUD_CTRU_NDSP
  else:
    doAssert not compiles(ctruNdspBackend)

proc checkRawFlags() =
  doAssert rawInitFlags({}) == 0'u32
  doAssert rawInitFlags({clipRoundoff}) == SOLOUD_CLIP_ROUNDOFF
  doAssert rawInitFlags({enableVisualization, leftHanded3d}) ==
    (SOLOUD_ENABLE_VISUALIZATION or SOLOUD_LEFT_HANDED_3D)
  doAssert rawInitFlags({clipRoundoff, noFpuRegisterChange}) ==
    (SOLOUD_CLIP_ROUNDOFF or SOLOUD_NO_FPU_REGISTER_CHANGE)

proc checkKnownBackends() =
  doAssert defaultBackend.isKnownBackend
  doAssert noSoundBackend.isKnownBackend
  doAssert nullBackend.isKnownBackend
  doAssert not backendMax.isKnownBackend

proc checkInitOptions() =
  let headless = initOptions(
    backend = nullBackend,
    sampleRate = 44100'u32,
    bufferSize = 2048'u32,
    channels = 2'u32
  )
  let raw = rawInitArgs(headless)
  doAssert raw.flags == SOLOUD_CLIP_ROUNDOFF
  doAssert raw.backend == SOLOUD_NULLDRIVER
  doAssert raw.sampleRate == 44100'u32
  doAssert raw.bufferSize == 2048'u32
  doAssert raw.channels == 2'u32

proc checkPlatformDefault() =
  when defined(playPlatformVita):
    doAssert platformDefaultBackend() == vitaHomebrewBackend
  elif defined(playPlatform3ds):
    doAssert platformDefaultBackend() == ctruNdspBackend
  else:
    doAssert platformDefaultBackend() == defaultBackend

when isMainModule:
  checkRawFlags()
  checkKnownBackends()
  checkInitOptions()
  checkPlatformDefault()
