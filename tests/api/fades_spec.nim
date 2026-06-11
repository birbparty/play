import std/os

import bddy
import common/test_helpers
import play
import play/bindings/soloud_raw as raw except Bus
import play/private/global_engine
import play/private/lifecycle as engine_lifecycle
import play/private/types as privateTypes

proc voiceVolume(handle: Handle): float32 =
  let engine = currentEngine()
  if engine == nil:
    return -1.0'f32

  let soloud = engine.rawHandle()
  if soloud == nil or not privateTypes.isValid(handle):
    return -1.0'f32

  float32(raw.Soloud_getVolume(soloud, handle.rawVoiceHandle))

proc pumpMix(samples = 1024'u32) =
  let engine = currentEngine()
  if engine == nil:
    return

  let soloud = engine.rawHandle()
  if soloud == nil:
    return

  var buffer: array[2048, cshort]
  raw.Soloud_mixSigned16(soloud, addr buffer[0], samples)

spec "public fade API":
  it "fades an arbitrary public handle volume":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var fadeResult: PlayResult
      var volume = -1.0'f32
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = play(soundResult.sound)
      fadeResult = fadeVolume(handle, 0.25'f32, 0.001)
      sleep(20)
      pumpMix()
      volume = voiceVolume(handle)
      soundResult.sound.dispose()
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      fadeResult.ok == true
      volume == 0.25'f32

  it "fades in public streamed music through the music bus":
    given:
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var valid = false
      var volume = -1.0'f32
      var stopped: PlayResult
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = fadeInMusic(musicResult.music, 0.001, 0.5'f32)
      valid = play.isValid(handle)
      sleep(20)
      pumpMix()
      volume = voiceVolume(handle)
      stopped = stop(handle)
      musicResult.music.dispose()
      shutdown()
    then:
      initResult.ok == true
      musicResult.ok == true
      valid == true
      volume == 0.5'f32
      stopped.ok == true

  it "fades out music and schedules stop after fade":
    given:
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var fadeResult: PlayResult
      var validAfterSchedule = false
      var validAfterStop = true
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = playMusic(musicResult.music)
      fadeResult = fadeOutMusic(handle, 0.001)
      validAfterSchedule = play.isValid(handle)
      sleep(30)
      pumpMix()
      validAfterStop = play.isValid(handle)
      musicResult.music.dispose()
      shutdown()
    then:
      initResult.ok == true
      musicResult.ok == true
      fadeResult.ok == true
      validAfterSchedule == true
      validAfterStop == false

  it "rejects invalid public fades safely":
    given:
      var uninitializedResult: PlayResult
      var initResult: PlayResult
      var invalidResult: PlayResult
      var fadeOutResult: PlayResult
      var fadeInHandle = noHandle
    act:
      uninitializedResult = fadeVolume(noHandle, 0.0'f32, 0.001)
      fadeInHandle = fadeInMusic(Music(nil), 0.001)
      initResult = init(initOptions(backend = nullBackend))
      invalidResult = fadeVolume(noHandle, 0.0'f32, 0.001)
      fadeOutResult = fadeOutMusic(noHandle, 0.001)
      shutdown()
    then:
      uninitializedResult.ok == false
      uninitializedResult.error.kind == invalidHandle
      fadeInHandle == noHandle
      initResult.ok == true
      invalidResult.ok == false
      invalidResult.error.kind == invalidHandle
      fadeOutResult.ok == false
      fadeOutResult.error.kind == invalidHandle

  it "rejects once-valid public handles after stop":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var stopResult: PlayResult
      var fadeResult: PlayResult
      var fadeOutResult: PlayResult
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = play(soundResult.sound)
      stopResult = stop(handle)
      fadeResult = fadeVolume(handle, 0.0'f32, 0.001)
      fadeOutResult = fadeOutMusic(handle, 0.001)
      soundResult.sound.dispose()
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      stopResult.ok == true
      fadeResult.ok == false
      fadeResult.error.kind == invalidHandle
      fadeOutResult.ok == false
      fadeOutResult.error.kind == invalidHandle

  it "does not expose explicit-engine fade helpers through the public facade":
    then:
      compiles(fadeVolume(currentEngine(), noHandle, 0.0'f32, 0.001)) == false
      compiles(fadeInMusic(currentEngine(), Music(nil), 0.001)) == false
      compiles(fadeOutMusic(currentEngine(), noHandle, 0.001)) == false
