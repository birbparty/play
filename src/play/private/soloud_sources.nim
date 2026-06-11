## SoLoud C++ source closure for Nim's C backend.
##
## Importing this module compiles the vendored generated C API boundary and the
## C++ implementation files it references. Paths are derived from this module's
## location so the closure works both as a Nimble dependency and through
## console-style `--path` injection.

import std/os

const
  playRoot = currentSourcePath.parentDir.parentDir.parentDir.parentDir
  soloudRoot = playRoot / "vendor" / "soloud"
  soloudInclude = soloudRoot / "include"
  soloudSrc = soloudRoot / "src"

{.passC: "-I" & soloudInclude.}
{.passC: "-DWITH_NOSOUND -DWITH_NULL".}

when defined(linux):
  {.passL: "-lstdc++".}

when defined(playPlatform3ds) or defined(playPlatformVita):
  {.passC: "-fno-exceptions -fno-rtti -std=gnu++11".}

template compileSoloud(path: static string) =
  {.compile: soloudSrc / path.}

compileSoloud "c_api/soloud_c.cpp"

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

compileSoloud "backend/nosound/soloud_nosound.cpp"
compileSoloud "backend/null/soloud_null.cpp"

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

compileSoloud "audiosource/ay/chipplayer.cpp"
compileSoloud "audiosource/ay/sndbuffer.cpp"
compileSoloud "audiosource/ay/sndchip.cpp"
compileSoloud "audiosource/ay/sndrender.cpp"
compileSoloud "audiosource/ay/soloud_ay.cpp"
compileSoloud "audiosource/monotone/soloud_monotone.cpp"
compileSoloud "audiosource/noise/soloud_noise.cpp"
compileSoloud "audiosource/openmpt/soloud_openmpt.cpp"
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
