import bddy
import common/test_helpers
import play/private/lifecycle
import play/soloud

const
  lifecycleCycles = 16
  rapidOperationCycles = 32
  voicePressureCount = 32
  stressVoiceLimit = minimumMaxActiveVoices + 4'u32

spec "host audio stress":
  it "survives repeated init and shutdown cycles":
    given:
      let engine = newEngine()
      var allCyclesOk = true
    act:
      for cycle in 0 ..< lifecycleCycles:
        let backend = if cycle mod 2 == 0: nullBackend else: noSoundBackend
        let initResult = engine.init(initOptions(backend = backend))
        let activeWhileRunning = engine.activeVoiceCount()
        engine.shutdown()
        let activeAfterShutdown = engine.activeVoiceCount()

        allCyclesOk = allCyclesOk and initResult.ok
        allCyclesOk = allCyclesOk and activeWhileRunning <= engine.activeVoiceLimit()
        allCyclesOk = allCyclesOk and activeAfterShutdown == 0'u32

      engine.destroy()
    then:
      allCyclesOk == true
      engine.isInitialized == false

  it "handles rapid load, play, stop, dispose operations":
    given:
      let engine = newEngine()
      let soundPath = fixturePath("generated", "tone_sfx.wav")
      var initResult: PlayResult
      var allOperationsOk = true
      var maxActiveSeen = 0'u32
      var activeAfterShutdown = 1'u32
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      for i in 0 ..< rapidOperationCycles:
        let soundResult = loadSound(soundPath)
        let handle = engine.playSound(soundResult.sound)
        let volumeResult = engine.setVolume(handle, float32((i mod 8) + 1) / 8'f32)
        let pauseResult = engine.pause(handle)
        let resumeResult = engine.resume(handle)
        let stopResult = engine.stop(handle)
        let activeNow = engine.activeVoiceCount()

        maxActiveSeen = max(maxActiveSeen, activeNow)
        allOperationsOk = allOperationsOk and soundResult.ok
        allOperationsOk = allOperationsOk and handle.isValid
        allOperationsOk = allOperationsOk and volumeResult.ok
        allOperationsOk = allOperationsOk and pauseResult.ok
        allOperationsOk = allOperationsOk and resumeResult.ok
        allOperationsOk = allOperationsOk and stopResult.ok
        allOperationsOk = allOperationsOk and activeNow <= engine.activeVoiceLimit()

        soundResult.sound.dispose()

      engine.shutdown()
      activeAfterShutdown = engine.activeVoiceCount()
      engine.destroy()
    then:
      initResult.ok == true
      allOperationsOk == true
      maxActiveSeen <= stressVoiceLimit or maxActiveSeen <= platformDefaultMaxActiveVoices()
      activeAfterShutdown == 0'u32

  it "bounds many concurrent voices within the configured limit":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var configResult: PlayResult
      var initResult: PlayResult
      var handles: seq[Handle]
      var activeAfterPressure = 0'u32
      var validAfterPressure = 0
      var stopFailures = 0
      var activeAfterStops = 0'u32
      var activeAfterShutdown = 1'u32
    act:
      configResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = stressVoiceLimit))
      initResult = engine.init(initOptions(backend = noSoundBackend))

      for _ in 0 ..< voicePressureCount:
        handles.add engine.playSound(soundResult.sound)

      activeAfterPressure = engine.activeVoiceCount()
      for handle in handles:
        if engine.isValid(handle):
          inc validAfterPressure
          let stopResult = engine.stop(handle)
          if not stopResult.ok:
            inc stopFailures

      activeAfterStops = engine.activeVoiceCount()
      engine.shutdown()
      activeAfterShutdown = engine.activeVoiceCount()
      soundResult.sound.dispose()
      engine.destroy()
    then:
      soundResult.ok == true
      configResult.ok == true
      initResult.ok == true
      handles.len == voicePressureCount
      activeAfterPressure == stressVoiceLimit
      validAfterPressure >= int(stressVoiceLimit - fixedBusVoiceReserve)
      stopFailures == 0
      activeAfterStops <= fixedBusVoiceReserve
      activeAfterShutdown == 0'u32
