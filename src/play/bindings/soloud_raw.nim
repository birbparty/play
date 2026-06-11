## Raw Nim imports for the small SoLoud C API subset used by play phase 1.
##
## This module intentionally mirrors the generated C API names and keeps the
## opaque handles as pointers. Higher-level play modules should wrap this API
## instead of re-exporting it directly.

{.warning[UnusedImport]: off.}
import play/soloud_compile
{.warning[UnusedImport]: on.}

type
  # soloud_c.h spells handles as `typedef void * Soloud` and then declares
  # parameters as `Soloud *`, but soloud_c.cpp exports the generated C boundary
  # as plain `void *`. Model the effective ABI here so Nim calls match the
  # linked symbols instead of the header's pointer-level artifact.
  Soloud* = pointer
  AudioSource* = pointer
  Bus* = pointer
  Wav* = pointer
  WavStream* = pointer
  VoiceHandle* = cuint
  SoloudResult* = cint

const
  SOLOUD_AUTO* = 0'u32
  SOLOUD_VITA_HOMEBREW* = 13'u32
  SOLOUD_CTRU_NDSP* = 14'u32
  SOLOUD_MINIAUDIO* = 15'u32
  SOLOUD_NOSOUND* = 16'u32
  SOLOUD_NULLDRIVER* = 17'u32
  SOLOUD_BACKEND_MAX* = 18'u32

  SOLOUD_CLIP_ROUNDOFF* = 1'u32
  SOLOUD_ENABLE_VISUALIZATION* = 2'u32
  SOLOUD_LEFT_HANDED_3D* = 4'u32
  SOLOUD_NO_FPU_REGISTER_CHANGE* = 8'u32

proc Soloud_create*(): Soloud {.importc, cdecl.}
proc Soloud_destroy*(aSoloud: Soloud) {.importc, cdecl.}
proc Soloud_init*(aSoloud: Soloud): SoloudResult {.importc, cdecl.}
proc Soloud_initEx*(
  aSoloud: Soloud,
  aFlags: cuint,
  aBackend: cuint,
  aSamplerate: cuint,
  aBufferSize: cuint,
  aChannels: cuint
): SoloudResult {.importc, cdecl.}
proc Soloud_pause*(aSoloud: Soloud): SoloudResult {.importc, cdecl.}
proc Soloud_resume*(aSoloud: Soloud): SoloudResult {.importc, cdecl.}
proc Soloud_deinit*(aSoloud: Soloud) {.importc, cdecl.}
proc Soloud_getErrorString*(aSoloud: Soloud, aErrorCode: cint): cstring {.importc, cdecl.}
proc Soloud_getBackendId*(aSoloud: Soloud): cuint {.importc, cdecl.}
proc Soloud_getBackendString*(aSoloud: Soloud): cstring {.importc, cdecl.}
proc Soloud_getBackendSamplerate*(aSoloud: Soloud): cuint {.importc, cdecl.}
proc Soloud_getBackendBufferSize*(aSoloud: Soloud): cuint {.importc, cdecl.}
proc Soloud_setGlobalVolume*(aSoloud: Soloud, aVolume: cfloat) {.importc, cdecl.}

proc Soloud_play*(aSoloud: Soloud, aSound: AudioSource): VoiceHandle {.importc, cdecl.}
proc Soloud_playEx*(
  aSoloud: Soloud,
  aSound: AudioSource,
  aVolume: cfloat,
  aPan: cfloat,
  aPaused: cint,
  aBus: VoiceHandle
): VoiceHandle {.importc, cdecl.}
proc Soloud_playBackground*(aSoloud: Soloud, aSound: AudioSource): VoiceHandle {.importc, cdecl.}
proc Soloud_playBackgroundEx*(
  aSoloud: Soloud,
  aSound: AudioSource,
  aVolume: cfloat,
  aPaused: cint,
  aBus: VoiceHandle
): VoiceHandle {.importc, cdecl.}
proc Soloud_stop*(aSoloud: Soloud, aVoiceHandle: VoiceHandle) {.importc, cdecl.}
proc Soloud_stopAll*(aSoloud: Soloud) {.importc, cdecl.}
proc Soloud_setPause*(aSoloud: Soloud, aVoiceHandle: VoiceHandle, aPause: cint) {.importc, cdecl.}
proc Soloud_setLooping*(aSoloud: Soloud, aVoiceHandle: VoiceHandle, aLooping: cint) {.importc, cdecl.}
proc Soloud_setVolume*(aSoloud: Soloud, aVoiceHandle: VoiceHandle, aVolume: cfloat) {.importc, cdecl.}
proc Soloud_isValidVoiceHandle*(aSoloud: Soloud, aVoiceHandle: VoiceHandle): cint {.importc, cdecl.}
proc Soloud_setMaxActiveVoiceCount*(aSoloud: Soloud, aVoiceCount: cuint): SoloudResult {.importc, cdecl.}

proc Soloud_fadeVolume*(aSoloud: Soloud, aVoiceHandle: VoiceHandle, aTo: cfloat, aTime: cdouble) {.importc, cdecl.}
proc Soloud_fadeGlobalVolume*(aSoloud: Soloud, aTo: cfloat, aTime: cdouble) {.importc, cdecl.}
proc Soloud_schedulePause*(aSoloud: Soloud, aVoiceHandle: VoiceHandle, aTime: cdouble) {.importc, cdecl.}
proc Soloud_scheduleStop*(aSoloud: Soloud, aVoiceHandle: VoiceHandle, aTime: cdouble) {.importc, cdecl.}

proc Soloud_mixSigned16*(aSoloud: Soloud, aBuffer: ptr cshort, aSamples: cuint) {.importc, cdecl.}

proc Bus_create*(): Bus {.importc, cdecl.}
proc Bus_destroy*(aBus: Bus) {.importc, cdecl.}
proc Bus_play*(aBus: Bus, aSound: AudioSource): VoiceHandle {.importc, cdecl.}
proc Bus_playEx*(
  aBus: Bus,
  aSound: AudioSource,
  aVolume: cfloat,
  aPan: cfloat,
  aPaused: cint
): VoiceHandle {.importc, cdecl.}
proc Bus_setVolume*(aBus: Bus, aVolume: cfloat) {.importc, cdecl.}
proc Bus_stop*(aBus: Bus) {.importc, cdecl.}

proc Wav_create*(): Wav {.importc, cdecl.}
proc Wav_destroy*(aWav: Wav) {.importc, cdecl.}
proc Wav_load*(aWav: Wav, aFilename: cstring): SoloudResult {.importc, cdecl.}
proc Wav_loadMem*(aWav: Wav, aMem: ptr uint8, aLength: cuint): SoloudResult {.importc, cdecl.}
proc Wav_setLooping*(aWav: Wav, aLoop: cint) {.importc, cdecl.}
proc Wav_setVolume*(aWav: Wav, aVolume: cfloat) {.importc, cdecl.}
proc Wav_stop*(aWav: Wav) {.importc, cdecl.}

proc WavStream_create*(): WavStream {.importc, cdecl.}
proc WavStream_destroy*(aWavStream: WavStream) {.importc, cdecl.}
proc WavStream_load*(aWavStream: WavStream, aFilename: cstring): SoloudResult {.importc, cdecl.}
proc WavStream_loadMem*(aWavStream: WavStream, aData: ptr uint8, aDataLen: cuint): SoloudResult {.importc, cdecl.}
proc WavStream_loadToMem*(aWavStream: WavStream, aFilename: cstring): SoloudResult {.importc, cdecl.}
proc WavStream_setLooping*(aWavStream: WavStream, aLoop: cint) {.importc, cdecl.}
proc WavStream_setVolume*(aWavStream: WavStream, aVolume: cfloat) {.importc, cdecl.}
proc WavStream_stop*(aWavStream: WavStream) {.importc, cdecl.}
