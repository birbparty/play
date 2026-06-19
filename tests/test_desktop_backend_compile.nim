## Desktop-backend compile guard (play-wb2).
##
## Proves the real implementation of the desktop closure's host backend is
## actually compiled in — not the `#if !defined(WITH_*)` stub that returns
## `NOT_IMPLEMENTED`. The host backend is per-OS: macOS compiles CoreAudio
## (`backend/coreaudio/soloud_coreaudio.cpp`, `WITH_COREAUDIO`); Linux/Windows
## compile miniaudio (`backend/miniaudio/soloud_miniaudio.cpp` + the header-only
## `miniaudio.h`, `WITH_MINIAUDIO`). See src/play/private/soloud_sources.nim.
##
## Discriminator (device-independent, headless-CI safe): requesting a specific
## backend that is NOT compiled in makes `Soloud::init` fall through every
## backend block and return `NOT_IMPLEMENTED` (see soloud.cpp:
## `if (!inited && aBackend != Soloud::AUTO) return NOT_IMPLEMENTED;`). When the
## backend IS compiled in, requesting it either opens a device (returns
## `SO_NO_ERROR`) or fails to open one (`UNKNOWN_ERROR`) — but never
## `NOT_IMPLEMENTED`. So `result != NOT_IMPLEMENTED` proves the backend built and
## linked, with no audio hardware required.
##
## This is the build-proof half of the desktop backend success criteria; the
## audible half is covered by tests/test_desktop_audible_backend.nim and the
## human-verification tasks (play-apf/nd0/f3r).
{.warning[UnusedImport]: off.}
import play/soloud_compile
{.warning[UnusedImport]: on.}

import play/bindings/soloud_raw

# vendor/soloud/include/soloud_error.h -> SOLOUD_ERRORS.NOT_IMPLEMENTED
const soloudNotImplemented = 6'i32

when defined(macosx):
  const hostBackend = SOLOUD_COREAUDIO
  const hostBackendName = "CoreAudio"
  const hostBackendDefine = "WITH_COREAUDIO / soloud_coreaudio.cpp"
else:
  const hostBackend = SOLOUD_MINIAUDIO
  const hostBackendName = "MiniAudio"
  const hostBackendDefine = "WITH_MINIAUDIO / soloud_miniaudio.cpp"

when isMainModule:
  when defined(playPlatformDesktop):
    let soloud = Soloud_create()
    doAssert soloud != nil

    # Explicitly request the host backend (non-AUTO). If it were not compiled
    # in, this returns NOT_IMPLEMENTED.
    let res = Soloud_initEx(
      soloud, 0'u32, hostBackend, SOLOUD_AUTO, SOLOUD_AUTO, 2'u32)

    doAssert int32(res) != soloudNotImplemented,
      hostBackendName & " backend not compiled in: Soloud_initEx returned " &
      "NOT_IMPLEMENTED — desktop closure is missing " & hostBackendDefine

    # When a device actually opened (res == 0, e.g. an audio-equipped runner),
    # the backend reports its name. Headless CI returns UNKNOWN_ERROR (res != 0)
    # and skips this stronger check.
    if int32(res) == 0:
      doAssert $Soloud_getBackendString(soloud) == hostBackendName,
        hostBackendName & " device opened but backend string was '" &
        $Soloud_getBackendString(soloud) & "'"

    # The Soloud destructor (~Soloud) calls deinit(), so destroy alone cleans up
    # whether or not a device was actually opened above.
    Soloud_destroy(soloud)
  else:
    # Console targets (3DS/Vita) intentionally do not compile the desktop host
    # backend; there is nothing to assert for it on those platforms.
    discard
