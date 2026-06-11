import std/os

import bddy
import common/test_helpers
import play/bindings/soloud_raw as raw
import play/private/lifecycle as privateLifecycle
import play/private/types as privateTypes
import play/soloud

proc voiceVolume(engine: privateLifecycle.Engine, handle: Handle): float32 =
  let soloud = engine.rawHandle()
  if soloud == nil or not handle.isValid:
    return -1.0'f32

  float32(raw.Soloud_getVolume(soloud, handle.rawVoiceHandle))

proc pumpMix(engine: privateLifecycle.Engine, samples = 1024'u32) =
  let soloud = engine.rawHandle()
  if soloud == nil:
    return

  var buffer: array[2048, cshort]
  raw.Soloud_mixSigned16(soloud, addr buffer[0], samples)

spec "SoLoud fade helpers":
  it "fades a valid sound handle volume":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var fadeResult: PlayResult
      var volume = -1.0'f32
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      handle = engine.playSound(soundResult.sound)
      fadeResult = engine.fadeVolume(handle, 0.25'f32, 0.001)
      sleep(20)
      engine.pumpMix()
      volume = engine.voiceVolume(handle)
      soundResult.sound.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      soundResult.ok == true
      handle.isValid == true
      fadeResult.ok == true
      volume == 0.25'f32

  it "fades in streamed music through the music bus":
    given:
      let engine = newEngine()
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var volume = -1.0'f32
      var stopped: PlayResult
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      handle = engine.fadeInMusic(musicResult.music, 0.001, 0.5'f32)
      sleep(20)
      engine.pumpMix()
      volume = engine.voiceVolume(handle)
      stopped = engine.stop(handle)
      musicResult.music.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      musicResult.ok == true
      handle.isValid == true
      volume == 0.5'f32
      stopped.ok == true

  it "fades out music and schedules stop after fade":
    given:
      let engine = newEngine()
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var fadeResult: PlayResult
      var validAfterSchedule = false
      var validAfterStop = true
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      handle = engine.playMusic(musicResult.music)
      fadeResult = engine.fadeOutMusic(handle, 0.001)
      validAfterSchedule = engine.isValid(handle)
      sleep(30)
      engine.pumpMix()
      validAfterStop = engine.isValid(handle)
      musicResult.music.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      musicResult.ok == true
      handle.isValid == true
      fadeResult.ok == true
      validAfterSchedule == true
      validAfterStop == false

  it "rejects invalid fades safely":
    given:
      let engine = newEngine()
      var uninitializedResult: PlayResult
      var initResult: PlayResult
      var invalidResult: PlayResult
      var fadeOutResult: PlayResult
    act:
      uninitializedResult = engine.fadeVolume(noHandle, 0.0'f32, 0.001)
      initResult = engine.init(initOptions(backend = nullBackend))
      invalidResult = engine.fadeVolume(noHandle, 0.0'f32, 0.001)
      fadeOutResult = engine.fadeOutMusic(noHandle, 0.001)
      engine.destroy()
    then:
      uninitializedResult.ok == false
      uninitializedResult.error.kind == invalidHandle
      initResult.ok == true
      invalidResult.ok == false
      invalidResult.error.kind == invalidHandle
      fadeOutResult.ok == false
      fadeOutResult.error.kind == invalidHandle
