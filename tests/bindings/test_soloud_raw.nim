import std/os

import play/bindings/soloud_raw

static:
  doAssert sizeof(cuint) == 4
  doAssert sizeof(cint) == 4
  doAssert sizeof(cfloat) == 4
  doAssert sizeof(cdouble) == 8
  doAssert SOLOUD_AUTO == 0'u32
  doAssert SOLOUD_VITA_HOMEBREW == 13'u32
  doAssert SOLOUD_CTRU_NDSP == 14'u32
  doAssert SOLOUD_MINIAUDIO == 15'u32
  doAssert SOLOUD_NOSOUND == 16'u32
  doAssert SOLOUD_NULLDRIVER == 17'u32
  doAssert SOLOUD_BACKEND_MAX == 18'u32
  doAssert SOLOUD_CLIP_ROUNDOFF == 1'u32

proc addLe16(data: var string, value: uint16) =
  data.add char(value and 0xff)
  data.add char((value shr 8) and 0xff)

proc addLe32(data: var string, value: uint32) =
  data.add char(value and 0xff)
  data.add char((value shr 8) and 0xff)
  data.add char((value shr 16) and 0xff)
  data.add char((value shr 24) and 0xff)

proc tinyWavData(): string =
  const
    channels = 1'u16
    sampleRate = 8000'u32
    bitsPerSample = 16'u16
    samples = 16'u32
    blockAlign = channels * (bitsPerSample div 8)
    byteRate = sampleRate * uint32(blockAlign)
    dataBytes = samples * uint32(blockAlign)

  result = "RIFF"
  result.addLe32(36'u32 + dataBytes)
  result.add "WAVEfmt "
  result.addLe32 16'u32
  result.addLe16 1'u16
  result.addLe16 channels
  result.addLe32 sampleRate
  result.addLe32 byteRate
  result.addLe16 blockAlign
  result.addLe16 bitsPerSample
  result.add "data"
  result.addLe32 dataBytes

  for i in 0'u32 ..< samples:
    let sample = if (i and 1'u32) == 0'u32: 1024'u16 else: 0'u16
    result.addLe16 sample

proc writeTinyWav(): string =
  let dir = getTempDir() / "play-soloud-raw-test"
  createDir dir
  result = dir / "tiny.wav"
  writeFile(result, tinyWavData())

proc checkBackend(backend: cuint, wavPath: string) =
  let soloud = Soloud_create()
  doAssert soloud != nil
  try:
    let result = Soloud_initEx(soloud, SOLOUD_CLIP_ROUNDOFF, backend, 44100'u32, 2048'u32, 2'u32)
    if result != 0:
      doAssert $Soloud_getErrorString(soloud, result) == ""

    doAssert result == 0
    doAssert Soloud_getBackendId(soloud) == backend
    doAssert Soloud_getBackendString(soloud) != nil
    doAssert Soloud_getBackendSamplerate(soloud) == 44100'u32
    doAssert Soloud_getBackendBufferSize(soloud) > 0'u32
    discard Soloud_pause(soloud)
    discard Soloud_resume(soloud)
    Soloud_setGlobalVolume(soloud, 0.5'f32)
    doAssert Soloud_setMaxActiveVoiceCount(soloud, 8'u32) == 0

    let wav = Wav_create()
    doAssert wav != nil
    try:
      doAssert Wav_loadMem(wav, nil, 0'u32) != 0
      doAssert Wav_load(wav, cstring(wavPath)) == 0
      Wav_setLooping(wav, 1)
      Wav_setVolume(wav, 0.25'f32)

      let handle = Soloud_play(soloud, wav)
      doAssert handle != 0'u32
      doAssert Soloud_isValidVoiceHandle(soloud, handle) != 0
      Soloud_setPause(soloud, handle, 1)
      Soloud_setLooping(soloud, handle, 1)
      Soloud_setVolume(soloud, handle, 0.5'f32)
      Soloud_fadeVolume(soloud, handle, 0.25'f32, 0.01)
      Soloud_schedulePause(soloud, handle, 0.01)
      Soloud_scheduleStop(soloud, handle, 0.02)
      Soloud_stop(soloud, handle)

      discard Soloud_playEx(soloud, wav, 0.75'f32, 0.0'f32, 1, 0'u32)
      discard Soloud_playBackground(soloud, wav)
      discard Soloud_playBackgroundEx(soloud, wav, 0.5'f32, 1, 0'u32)

      let bus = Bus_create()
      doAssert bus != nil
      try:
        discard Bus_play(bus, wav)
        discard Bus_playEx(bus, wav, 0.5'f32, 0.0'f32, 1)
        Bus_setVolume(bus, 0.75'f32)
        Bus_stop(bus)
      finally:
        Bus_destroy(bus)

      Wav_stop(wav)
    finally:
      Wav_destroy(wav)

    var buffer: array[128, cshort]
    Soloud_mixSigned16(soloud, addr buffer[0], 64'u32)

    Soloud_stop(soloud, 0'u32)
    Soloud_stopAll(soloud)
    Soloud_deinit(soloud)
  finally:
    Soloud_destroy(soloud)

proc checkStreams(wavPath: string) =
  let stream = WavStream_create()
  doAssert stream != nil
  try:
    doAssert WavStream_loadMem(stream, nil, 0'u32) != 0
    doAssert WavStream_load(stream, cstring(wavPath)) == 0
    WavStream_setLooping(stream, 0)
    WavStream_setVolume(stream, 0.25'f32)
    WavStream_stop(stream)
    doAssert WavStream_loadToMem(stream, cstring(wavPath)) == 0
  finally:
    WavStream_destroy(stream)

when isMainModule:
  let wavPath = writeTinyWav()
  try:
    checkBackend(SOLOUD_NOSOUND, wavPath)
    checkBackend(SOLOUD_NULLDRIVER, wavPath)
    checkStreams(wavPath)
  finally:
    removeFile(wavPath)
