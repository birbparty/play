## Desktop audible-backend CI gate.
##
## Two parts, both desktop-only:
##
## Part A (always on, device-free): a compiled-backend-set guard. Requesting a
## specific backend that is NOT compiled in makes `Soloud::init` fall through and
## return `NOT_IMPLEMENTED` (see soloud.cpp:
## `if (!inited && aBackend != Soloud::AUTO) return NOT_IMPLEMENTED;`). So
## `result != NOT_IMPLEMENTED` proves the platform's real backend was compiled
## and linked, with no audio hardware required. On macOS the expected backend is
## CoreAudio (WITH_COREAUDIO); on Linux/Windows it is MiniAudio (WITH_MINIAUDIO).
## This catches a dropped or mis-`when`'d backend arm even on a headless runner.
##
## Part B (gated by the PLAY_REQUIRE_AUDIBLE env var): the real regression gate.
## `init(initOptions())` uses SoLoud AUTO; on a host with a working device it must
## resolve to an audible backend, NOT the silent NoSound fallback. When
## PLAY_REQUIRE_AUDIBLE=1 (set on macOS CI, which has a CoreAudio device) this is
## a hard assertion. Otherwise it only logs the resolved backend for diagnostics,
## so it stays non-fatal on hosts without an audio device (headless Linux,
## best-effort Windows).
import std/os

import play
import play/bindings/soloud_raw

# vendor/soloud/include/soloud_error.h -> SOLOUD_ERRORS.NOT_IMPLEMENTED
const soloudNotImplemented = 6'i32

when defined(macosx):
  const expectedBackend = SOLOUD_COREAUDIO
  const expectedBackendName = "CoreAudio"
else:
  const expectedBackend = SOLOUD_MINIAUDIO
  const expectedBackendName = "MiniAudio"

proc partACompiledBackendGuard() =
  let soloud = Soloud_create()
  doAssert soloud != nil

  # Request the platform's real backend explicitly (non-AUTO). If it were not
  # compiled in, this returns NOT_IMPLEMENTED.
  let res = Soloud_initEx(
    soloud, 0'u32, expectedBackend, SOLOUD_AUTO, SOLOUD_AUTO, 2'u32)

  doAssert int32(res) != soloudNotImplemented,
    expectedBackendName & " backend not compiled into the desktop closure: " &
    "Soloud_initEx returned NOT_IMPLEMENTED — missing the WITH_* define / .cpp"

  # When a device actually opened (res == 0) the backend reports its name.
  if int32(res) == 0:
    doAssert $Soloud_getBackendString(soloud) == expectedBackendName,
      expectedBackendName & " device opened but backend string was '" &
      $Soloud_getBackendString(soloud) & "'"

  # The Soloud destructor (~Soloud) calls deinit(), so destroy alone cleans up
  # whether or not a device was actually opened above.
  Soloud_destroy(soloud)

proc partBAudibleAutoGate() =
  let requireAudible = getEnv("PLAY_REQUIRE_AUDIBLE") == "1"
  let started = init(initOptions())  # SoLoud AUTO
  try:
    if not started.ok:
      doAssert not requireAudible,
        "PLAY_REQUIRE_AUDIBLE=1 but init(AUTO) failed: " & started.error.message
      echo "desktop-audible: init(AUTO) failed (no device?): ", started.error.message
      return

    let name = backendString()
    let audible = isAudibleBackend()
    echo "desktop-audible: AUTO resolved to '", name, "' (audible=", audible, ")"

    if requireAudible:
      doAssert audible,
        "PLAY_REQUIRE_AUDIBLE=1 but AUTO resolved to a silent backend '" & name &
        "' — desktop init landed on NoSound/NULL instead of a real device"
  finally:
    # Safe no-op when init failed / nothing was initialized.
    shutdown()

when isMainModule:
  when defined(playPlatformDesktop):
    partACompiledBackendGuard()
    partBAudibleAutoGate()
  else:
    # Console targets (3DS/Vita) compile their own real backend, not the desktop
    # CoreAudio/MiniAudio closure; there is nothing to assert here for them.
    discard
