## Backend selection and SoLoud init option mapping.
##
## This module is the typed boundary between play's future safe wrapper and the
## raw SoLoud C backend IDs.

import play/bindings/soloud_raw

type
  Backend* = distinct cuint

  InitFlag* = enum
    clipRoundoff
    enableVisualization
    leftHanded3d
    noFpuRegisterChange

  InitFlags* = set[InitFlag]

  InitOptions* = object
    backend*: Backend
    flags*: InitFlags
    sampleRate*: cuint
    bufferSize*: cuint
    channels*: cuint

const
  defaultBackend* = Backend(SOLOUD_AUTO)
  noSoundBackend* = Backend(SOLOUD_NOSOUND)
  nullBackend* = Backend(SOLOUD_NULLDRIVER)
  backendMax* = Backend(SOLOUD_BACKEND_MAX)

when defined(playPlatformVita):
  const vitaHomebrewBackend* = Backend(SOLOUD_VITA_HOMEBREW)

when defined(playPlatform3ds) and defined(playHasCtruNdspBackend):
  const playCtruNdspBackendId* {.intdefine.} = -1
  static:
    doAssert playCtruNdspBackendId >= 0,
      "define playCtruNdspBackendId after vendored SoLoud includes CTRU_NDSP"
  const ctruNdspBackend* = Backend(uint32(playCtruNdspBackendId))

proc `==`*(a, b: Backend): bool {.borrow.}

proc rawBackendId*(backend: Backend): cuint =
  cuint(backend)

proc isKnownBackend*(backend: Backend): bool =
  rawBackendId(backend) < rawBackendId(backendMax)

proc rawInitFlags*(flags: InitFlags): cuint =
  if clipRoundoff in flags:
    result = result or SOLOUD_CLIP_ROUNDOFF
  if enableVisualization in flags:
    result = result or SOLOUD_ENABLE_VISUALIZATION
  if leftHanded3d in flags:
    result = result or SOLOUD_LEFT_HANDED_3D
  if noFpuRegisterChange in flags:
    result = result or SOLOUD_NO_FPU_REGISTER_CHANGE

proc platformDefaultBackend*(): Backend =
  when defined(playPlatformVita):
    vitaHomebrewBackend
  elif defined(playPlatform3ds) and defined(playHasCtruNdspBackend):
    ctruNdspBackend
  else:
    defaultBackend

proc initOptions*(
  backend = platformDefaultBackend(),
  flags: InitFlags = {clipRoundoff},
  sampleRate = SOLOUD_AUTO,
  bufferSize = SOLOUD_AUTO,
  channels = 2'u32
): InitOptions =
  InitOptions(
    backend: backend,
    flags: flags,
    sampleRate: sampleRate,
    bufferSize: bufferSize,
    channels: channels
  )

proc rawInitArgs*(options: InitOptions): tuple[
  flags: cuint,
  backend: cuint,
  sampleRate: cuint,
  bufferSize: cuint,
  channels: cuint
] =
  (
    flags: rawInitFlags(options.flags),
    backend: rawBackendId(options.backend),
    sampleRate: options.sampleRate,
    bufferSize: options.bufferSize,
    channels: options.channels
  )
