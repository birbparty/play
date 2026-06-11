import bddy
import common/test_helpers
import play

spec "public handle operations API":
  it "rejects dead handles before init":
    given:
      var pauseResult: PlayResult
      var resumeResult: PlayResult
      var stopResult: PlayResult
      var loopResult: PlayResult
      var volumeResult: PlayResult
    act:
      pauseResult = pause(noHandle)
      resumeResult = resume(noHandle)
      stopResult = stop(noHandle)
      loopResult = setLooping(noHandle, true)
      volumeResult = setVolume(noHandle, 1.0'f32)
    then:
      noHandle.isValid == false
      pauseResult.ok == false
      pauseResult.error.kind == invalidHandle
      resumeResult.ok == false
      resumeResult.error.kind == invalidHandle
      stopResult.ok == false
      stopResult.error.kind == invalidHandle
      loopResult.ok == false
      loopResult.error.kind == invalidHandle
      volumeResult.ok == false
      volumeResult.error.kind == invalidHandle

  it "pauses, resumes, loops, changes volume, and stops a live sound handle":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var validBeforeStop = false
      var pauseResult: PlayResult
      var resumeResult: PlayResult
      var loopResult: PlayResult
      var volumeResult: PlayResult
      var stopResult: PlayResult
      var secondStopResult: PlayResult
      var validAfterStop = true
    act:
      initResult = init(initOptions(backend = noSoundBackend))
      handle = play(soundResult.sound)
      validBeforeStop = handle.isValid
      pauseResult = pause(handle)
      resumeResult = resume(handle)
      loopResult = setLooping(handle, true)
      volumeResult = setVolume(handle, 0.5'f32)
      stopResult = stop(handle)
      secondStopResult = stop(handle)
      validAfterStop = handle.isValid
      soundResult.sound.dispose()
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      validBeforeStop == true
      pauseResult.ok == true
      resumeResult.ok == true
      loopResult.ok == true
      volumeResult.ok == true
      stopResult.ok == true
      secondStopResult.ok == false
      secondStopResult.error.kind == invalidHandle
      validAfterStop == false

  it "invalidates live handles after shutdown":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var validBeforeShutdown = false
      var validAfterShutdown = true
      var pauseAfterShutdown: PlayResult
    act:
      initResult = init(initOptions(backend = noSoundBackend))
      handle = play(soundResult.sound)
      validBeforeShutdown = handle.isValid
      shutdown()
      validAfterShutdown = handle.isValid
      pauseAfterShutdown = pause(handle)
      soundResult.sound.dispose()
    then:
      initResult.ok == true
      soundResult.ok == true
      validBeforeShutdown == true
      validAfterShutdown == false
      pauseAfterShutdown.ok == false
      pauseAfterShutdown.error.kind == invalidHandle

  it "plays and stops a public handle under NULL backend":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var stopResult: PlayResult
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = play(soundResult.sound)
      stopResult = stop(handle)
      soundResult.sound.dispose()
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      handle != noHandle
      stopResult.ok == true

  it "does not expose raw voice ids through the public facade":
    then:
      compiles(Handle(123'u32)) == false
      compiles(uint32(noHandle)) == false
      compiles(noHandle.id) == false
      compiles(rawVoiceHandle(noHandle)) == false
      compiles(handleFromRaw(1'u32)) == false
      compiles(pause(currentEngine(), noHandle)) == false
      compiles(stop(currentEngine(), noHandle)) == false
