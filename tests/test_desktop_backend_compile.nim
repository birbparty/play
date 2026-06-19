## Desktop-backend compile guard (play-wb2).
##
## Proves the `WITH_MINIAUDIO` real implementation of
## `backend/miniaudio/soloud_miniaudio.cpp` (which pulls in the header-only
## `miniaudio.h`) is actually compiled into the desktop closure — not the
## `#if !defined(WITH_MINIAUDIO)` stub that returns `NOT_IMPLEMENTED`.
##
## Discriminator (device-independent, headless-CI safe): requesting a specific
## backend that is NOT compiled in makes `Soloud::init` fall through every
## backend block and return `NOT_IMPLEMENTED` (see soloud.cpp:
## `if (!inited && aBackend != Soloud::AUTO) return NOT_IMPLEMENTED;`). When the
## miniaudio backend IS compiled in, requesting it either opens a device (returns
## `SO_NO_ERROR`) or fails to open one (`UNKNOWN_ERROR`) — but never
## `NOT_IMPLEMENTED`. So `result != NOT_IMPLEMENTED` proves the backend built and
## linked, with no audio hardware required.
##
## This is the build-proof half of the desktop miniaudio success criteria; the
## audible half is covered by the human-verification tasks (play-apf/nd0/f3r).
{.warning[UnusedImport]: off.}
import play/soloud_compile
{.warning[UnusedImport]: on.}

import play/bindings/soloud_raw

# vendor/soloud/include/soloud_error.h -> SOLOUD_ERRORS.NOT_IMPLEMENTED
const soloudNotImplemented = 6'i32

when isMainModule:
  when defined(playPlatformDesktop):
    let soloud = Soloud_create()
    doAssert soloud != nil

    # Explicitly request the miniaudio backend (non-AUTO). If WITH_MINIAUDIO were
    # not compiled in, this returns NOT_IMPLEMENTED.
    let res = Soloud_initEx(
      soloud, 0'u32, SOLOUD_MINIAUDIO, SOLOUD_AUTO, SOLOUD_AUTO, 2'u32)

    doAssert int32(res) != soloudNotImplemented,
      "miniaudio backend not compiled in: Soloud_initEx(MINIAUDIO) returned " &
      "NOT_IMPLEMENTED — desktop closure is missing WITH_MINIAUDIO / " &
      "soloud_miniaudio.cpp"

    # The Soloud destructor (~Soloud) calls deinit(), so destroy alone cleans up
    # whether or not a device was actually opened above.
    Soloud_destroy(soloud)
  else:
    # Console targets (3DS/Vita) intentionally do not compile WITH_MINIAUDIO;
    # there is nothing to assert for the desktop backend on those platforms.
    discard
