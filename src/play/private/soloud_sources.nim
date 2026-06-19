## SoLoud C++ source closure for Nim's C backend.
##
## Importing this module compiles the vendored generated C API boundary and the
## C++ implementation files it references. Paths are derived from this module's
## location so the closure works both as a Nimble dependency and through
## console-style `--path` injection.

import std/os

const
  sourceDir = currentSourcePath.parentDir
  installedPackageRoot = sourceDir.parentDir.parentDir
  sourceTreeRoot = installedPackageRoot.parentDir
  soloudRoot =
    when dirExists(installedPackageRoot / "vendor" / "soloud"):
      installedPackageRoot / "vendor" / "soloud"
    else:
      sourceTreeRoot / "vendor" / "soloud"
  soloudInclude = soloudRoot / "include"
  soloudSrc = soloudRoot / "src"

{.passC: "-I" & soloudInclude.}

# Keep backend enablement explicit. Host builds prove the generated C API
# against headless backends; console builds compile their real platform backend.
when defined(playPlatform3ds):
  {.passC: "-DWITH_CTRU_NDSP".}
elif defined(playPlatformVita):
  {.passC: "-DWITH_VITA_HOMEBREW".}
elif defined(macosx):
  # macOS: SoLoud's native CoreAudio (AudioToolbox AudioQueue) backend. The
  # bundled miniaudio is from ~2020 and its ma_device_init returns MA_NO_BACKEND
  # (-103) on Apple Silicon, so AUTO falls through to NOSOUND and the app is
  # silent. The native CoreAudio backend uses the long-stable AudioQueue API and
  # works on Apple Silicon. AudioToolbox is already linked for macOS below.
  {.passC: "-DWITH_NOSOUND -DWITH_NULL -DWITH_COREAUDIO".}
else:
  {.passC: "-DWITH_NOSOUND -DWITH_NULL -DWITH_MINIAUDIO".}

when defined(linux):
  {.passL: "-lstdc++".}

# Desktop miniaudio link requirements, co-located for single-block rollback.
# Kept here (not nim.cfg) so console nim c/check passes never see them. Guarded
# by playPlatformDesktop + host OS to stay out of the console frozen-line digest.
# miniaudio dlopen's libasound/libpulse at runtime, so -lasound is intentionally
# not linked here (verify on a Linux target instead).
when defined(playPlatformDesktop) and defined(linux):
  {.passL: "-ldl -lpthread -lm".}
# macOS is now exercised by the desktop-audible-backend CI job (macos-latest),
# which builds this closure and asserts AUTO resolves to an audible backend, so
# the CoreAudio/AudioToolbox link block is CI-covered. The Windows block remains
# best-effort (windows-latest runs continue-on-error); verify it on the target
# host when touching it.
when defined(playPlatformDesktop) and defined(macosx):
  {.passL: "-framework CoreAudio -framework AudioToolbox -framework CoreFoundation".}
when defined(playPlatformDesktop) and defined(windows):
  {.passL: "-lole32 -lwinmm".}

when defined(playPlatform3ds) or defined(playPlatformVita):
  {.passC: "-fno-exceptions -fno-rtti -std=gnu++11".}

template compileSoloud(path: static string) =
  {.compile: soloudSrc / path.}

# Generated extern-C API boundary.
compileSoloud "c_api/soloud_c.cpp"

# Core engine implementation.
compileSoloud "core/soloud.cpp"
compileSoloud "core/soloud_audiosource.cpp"
compileSoloud "core/soloud_bus.cpp"
compileSoloud "core/soloud_core_3d.cpp"
compileSoloud "core/soloud_core_basicops.cpp"
compileSoloud "core/soloud_core_faderops.cpp"
compileSoloud "core/soloud_core_filterops.cpp"
compileSoloud "core/soloud_core_getters.cpp"
compileSoloud "core/soloud_core_setters.cpp"
compileSoloud "core/soloud_core_voicegroup.cpp"
compileSoloud "core/soloud_core_voiceops.cpp"
compileSoloud "core/soloud_fader.cpp"
compileSoloud "core/soloud_fft.cpp"
compileSoloud "core/soloud_fft_lut.cpp"
compileSoloud "core/soloud_file.cpp"
compileSoloud "core/soloud_filter.cpp"
compileSoloud "core/soloud_misc.cpp"
compileSoloud "core/soloud_queue.cpp"
compileSoloud "core/soloud_thread.cpp"

# Backends enabled by the WITH_* defines above.
when defined(playPlatform3ds):
  compileSoloud "backend/ctru_ndsp/soloud_ctru_ndsp.cpp"
elif defined(playPlatformVita):
  compileSoloud "backend/vita_homebrew/soloud_vita_homebrew.cpp"
elif defined(macosx):
  compileSoloud "backend/nosound/soloud_nosound.cpp"
  compileSoloud "backend/null/soloud_null.cpp"
  compileSoloud "backend/coreaudio/soloud_coreaudio.cpp"
else:
  compileSoloud "backend/nosound/soloud_nosound.cpp"
  compileSoloud "backend/null/soloud_null.cpp"
  compileSoloud "backend/miniaudio/soloud_miniaudio.cpp"

# Filter wrappers referenced by the generated C API.
compileSoloud "filter/soloud_bassboostfilter.cpp"
compileSoloud "filter/soloud_biquadresonantfilter.cpp"
compileSoloud "filter/soloud_dcremovalfilter.cpp"
compileSoloud "filter/soloud_duckfilter.cpp"
compileSoloud "filter/soloud_echofilter.cpp"
compileSoloud "filter/soloud_eqfilter.cpp"
compileSoloud "filter/soloud_fftfilter.cpp"
compileSoloud "filter/soloud_flangerfilter.cpp"
compileSoloud "filter/soloud_freeverbfilter.cpp"
compileSoloud "filter/soloud_lofifilter.cpp"
compileSoloud "filter/soloud_robotizefilter.cpp"
compileSoloud "filter/soloud_waveshaperfilter.cpp"

# Audio source wrappers referenced by the generated C API. Keep this explicit
# and reconcile it with docs/soloud-vendor-audit.md when the vendored snapshot
# changes; do not replace it with a broad source glob.
compileSoloud "audiosource/ay/chipplayer.cpp"
compileSoloud "audiosource/ay/sndbuffer.cpp"
compileSoloud "audiosource/ay/sndchip.cpp"
compileSoloud "audiosource/ay/sndrender.cpp"
compileSoloud "audiosource/ay/soloud_ay.cpp"
compileSoloud "audiosource/monotone/soloud_monotone.cpp"
compileSoloud "audiosource/noise/soloud_noise.cpp"
# OpenMPT is satisfied through SoLoud's dynamic loader shim, not direct
# libopenmpt linkage. Console targets do not provide dlopen/dlfcn, and phase 1
# does not expose module playback, so they link a no-op shim instead.
compileSoloud "audiosource/openmpt/soloud_openmpt.cpp"
when defined(playPlatform3ds) or defined(playPlatformVita):
  {.compile: sourceDir / "soloud_openmpt_stub.c".}
else:
  compileSoloud "audiosource/openmpt/soloud_openmpt_dll.c"
compileSoloud "audiosource/sfxr/soloud_sfxr.cpp"
compileSoloud "audiosource/speech/darray.cpp"
compileSoloud "audiosource/speech/klatt.cpp"
compileSoloud "audiosource/speech/resonator.cpp"
compileSoloud "audiosource/speech/soloud_speech.cpp"
compileSoloud "audiosource/speech/tts.cpp"
compileSoloud "audiosource/tedsid/sid.cpp"
compileSoloud "audiosource/tedsid/soloud_tedsid.cpp"
compileSoloud "audiosource/tedsid/ted.cpp"
compileSoloud "audiosource/vic/soloud_vic.cpp"
compileSoloud "audiosource/vizsn/soloud_vizsn.cpp"
compileSoloud "audiosource/wav/dr_impl.cpp"
compileSoloud "audiosource/wav/soloud_wav.cpp"
compileSoloud "audiosource/wav/soloud_wavstream.cpp"
compileSoloud "audiosource/wav/stb_vorbis.c"
