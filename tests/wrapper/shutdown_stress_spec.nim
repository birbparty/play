import bddy
import common/test_helpers
import play/private/lifecycle as privateLifecycle
import play/soloud

spec "SoLoud shutdown and cleanup stress":
  it "survives repeated load, play, stop, shutdown, and reinit cycles":
    given:
      let engine = newEngine()
      let soundPath = fixturePath("generated", "tone_sfx.wav")
      let musicPath = fixturePath("generated", "tone_music.ogg")
      var allCyclesOk = true
    act:
      for _ in 0 ..< 5:
        let initResult = engine.init(initOptions(backend = nullBackend))
        let soundResult = loadSound(soundPath)
        let musicResult = loadMusic(musicPath)
        let soundHandle = engine.playSound(soundResult.sound)
        let musicHandle = engine.playMusic(musicResult.music)
        let stoppedSound = engine.stop(soundHandle)
        let stoppedMusic = engine.stop(musicHandle)
        let voiceCountAfterStops = engine.activeVoiceCount()
        engine.shutdown()
        let voiceCountAfterShutdown = engine.activeVoiceCount()

        allCyclesOk = allCyclesOk and initResult.ok and soundResult.ok and musicResult.ok
        allCyclesOk = allCyclesOk and soundHandle.isValid and musicHandle.isValid
        allCyclesOk = allCyclesOk and stoppedSound.ok and stoppedMusic.ok
        allCyclesOk = allCyclesOk and voiceCountAfterStops <= 3'u32
        allCyclesOk = allCyclesOk and voiceCountAfterShutdown == 0'u32
        soundResult.sound.dispose()
        musicResult.music.dispose()
      engine.destroy()
    then:
      allCyclesOk == true
      engine.isInitialized == false

  it "shutdown stops active voices before assets are destroyed":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var soundHandle = noHandle
      var musicHandle = noHandle
      var activeBeforeShutdown = 0'u32
      var validBeforeShutdown = false
      var activeAfterShutdown = 1'u32
      var validAfterShutdown = true
      var pauseAfterShutdown: PlayResult
      var reinitResult: PlayResult
      var replayHandle = noHandle
      var replayValid = false
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      soundHandle = engine.playSound(soundResult.sound)
      musicHandle = engine.playMusic(musicResult.music)
      activeBeforeShutdown = engine.activeVoiceCount()
      validBeforeShutdown = engine.isValid(soundHandle) and engine.isValid(musicHandle)
      engine.shutdown()
      activeAfterShutdown = engine.activeVoiceCount()
      validAfterShutdown = engine.isValid(soundHandle) or engine.isValid(musicHandle)
      pauseAfterShutdown = engine.pause(soundHandle)
      reinitResult = engine.init(initOptions(backend = nullBackend))
      replayHandle = engine.playSound(soundResult.sound)
      replayValid = engine.isValid(replayHandle)
      soundResult.sound.dispose()
      musicResult.music.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      soundResult.ok == true
      musicResult.ok == true
      activeBeforeShutdown > 0'u32
      validBeforeShutdown == true
      activeAfterShutdown == 0'u32
      validAfterShutdown == false
      pauseAfterShutdown.ok == false
      pauseAfterShutdown.error.kind == invalidHandle
      reinitResult.ok == true
      replayValid == true

  it "failed loads do not poison later init or successful loads":
    given:
      let engine = newEngine()
      let missing = fixturePath("generated", "missing-after-failure.wav")
      let invalid = fixturePath("generated", "README.md")
      let valid = fixturePath("generated", "tone_sfx.wav")
      var missingResult: SoundResult
      var invalidResult: MusicResult
      var firstInit: PlayResult
      var secondInit: PlayResult
      var validSound: SoundResult
      var handle = noHandle
      var validHandle = false
    act:
      missingResult = loadSound(missing)
      invalidResult = loadMusic(invalid)
      firstInit = engine.init(initOptions(backend = nullBackend))
      engine.shutdown()
      secondInit = engine.init(initOptions(backend = nullBackend))
      validSound = loadSound(valid)
      handle = engine.playSound(validSound.sound)
      validHandle = engine.isValid(handle)
      validSound.sound.dispose()
      engine.destroy()
    then:
      missingResult.ok == false
      missingResult.error.kind == loadFailed
      invalidResult.ok == false
      invalidResult.error.kind == loadFailed
      invalidResult.music.isDisposed == true
      firstInit.ok == true
      secondInit.ok == true
      validSound.ok == true
      validHandle == true
