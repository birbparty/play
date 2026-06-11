import bddy
import common/test_helpers
import play/handles
import play/soloud

spec "SoLoud voice handle wrapper operations":
  it "checks dead handles cheaply and safely":
    given:
      let engine = newEngine()
      var initResult: PlayResult
      var valid = true
      var pauseResult: PlayResult
      var stopResult: PlayResult
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      valid = engine.isValid(noHandle)
      pauseResult = engine.pause(noHandle)
      stopResult = engine.stop(noHandle)
      engine.destroy()
    then:
      initResult.ok == true
      valid == false
      pauseResult.ok == false
      pauseResult.error.kind == invalidHandle
      stopResult.ok == false
      stopResult.error.kind == invalidHandle

  it "pauses, resumes, loops, changes volume, and stops a sound handle":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var pauseResult: PlayResult
      var resumeResult: PlayResult
      var loopResult: PlayResult
      var volumeResult: PlayResult
      var stopResult: PlayResult
      var secondStopResult: PlayResult
      var validBeforeStop = false
      var validAfterStop = true
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      handle = engine.playSound(soundResult.sound)
      validBeforeStop = engine.isValid(handle)
      pauseResult = engine.pause(handle)
      resumeResult = engine.resume(handle)
      loopResult = engine.setLooping(handle, true)
      volumeResult = engine.setVolume(handle, 0.5'f32)
      stopResult = engine.stop(handle)
      secondStopResult = engine.stop(handle)
      validAfterStop = engine.isValid(handle)
      soundResult.sound.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      soundResult.ok == true
      handle.isValid == true
      validBeforeStop == true
      pauseResult.ok == true
      resumeResult.ok == true
      loopResult.ok == true
      volumeResult.ok == true
      stopResult.ok == true
      secondStopResult.ok == false
      secondStopResult.error.kind == invalidHandle
      validAfterStop == false

  it "plays streamed music and rejects operations after stop":
    given:
      let engine = newEngine()
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var stopped: PlayResult
      var pauseAfterStop: PlayResult
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      handle = engine.playMusic(musicResult.music)
      stopped = engine.stop(handle)
      pauseAfterStop = engine.pause(handle)
      musicResult.music.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      musicResult.ok == true
      handle.isValid == true
      stopped.ok == true
      pauseAfterStop.ok == false
      pauseAfterStop.error.kind == invalidHandle

  it "rejects operations when the engine is not initialized":
    given:
      let engine = newEngine()
    then:
      engine.isValid(noHandle) == false
      engine.pause(noHandle).error.kind == invalidHandle
      engine.resume(noHandle).error.kind == invalidHandle
      engine.setLooping(noHandle, true).error.kind == invalidHandle
      engine.setVolume(noHandle, 1.0'f32).error.kind == invalidHandle

  it "runs handle operations under NOSOUND backend":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var pauseResult: PlayResult
      var stopResult: PlayResult
    act:
      initResult = engine.init(initOptions(backend = noSoundBackend))
      handle = engine.playSound(soundResult.sound)
      pauseResult = engine.pause(handle)
      stopResult = engine.stop(handle)
      soundResult.sound.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      soundResult.ok == true
      handle.isValid == true
      pauseResult.ok == true
      stopResult.ok == true
