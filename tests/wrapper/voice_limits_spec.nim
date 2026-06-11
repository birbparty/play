import bddy
import common/test_helpers
import play/private/lifecycle
import play/soloud

spec "SoLoud voice limit policy":
  it "uses documented platform default voice limits":
    given:
      const expectedPlatformDefault =
        when defined(playPlatformVita):
          vitaDefaultMaxActiveVoices
        elif defined(playPlatform3ds):
          n3dsDefaultMaxActiveVoices
        else:
          desktopDefaultMaxActiveVoices
    then:
      desktopDefaultMaxActiveVoices == 16'u32
      vitaDefaultMaxActiveVoices == 12'u32
      n3dsDefaultMaxActiveVoices == 10'u32
      fixedBusVoiceReserve == 3'u32
      minimumMaxActiveVoices == 4'u32
      platformDefaultMaxActiveVoices() == expectedPlatformDefault

  it "applies default active voice limit during init":
    given:
      let engine = newEngine()
      var initResult: PlayResult
      var activeLimit = 0'u32
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      activeLimit = engine.activeVoiceLimit()
      engine.destroy()
    then:
      initResult.ok == true
      activeLimit == platformDefaultMaxActiveVoices()

  it "applies custom active voice limit before init":
    given:
      let engine = newEngine()
      var configResult: PlayResult
      var initResult: PlayResult
      var activeLimit = 0'u32
    act:
      configResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = 4'u32))
      initResult = engine.init(initOptions(backend = nullBackend))
      activeLimit = engine.activeVoiceLimit()
      engine.destroy()
    then:
      configResult.ok == true
      initResult.ok == true
      activeLimit == 4'u32

  it "rejects invalid, bus-starving, or late voice limit configuration":
    given:
      let engine = newEngine()
      var invalidResult: PlayResult
      var busStarvingResult: PlayResult
      var initResult: PlayResult
      var lateResult: PlayResult
    act:
      invalidResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = 0'u32))
      busStarvingResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = fixedBusVoiceReserve))
      initResult = engine.init(initOptions(backend = nullBackend))
      lateResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = 4'u32))
      engine.destroy()
    then:
      invalidResult.ok == false
      invalidResult.error.kind == initFailed
      busStarvingResult.ok == false
      busStarvingResult.error.kind == initFailed
      initResult.ok == true
      lateResult.ok == false
      lateResult.error.kind == initFailed

  it "bounds active mixed voices under the minimum usable voice limit":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var configResult: PlayResult
      var initResult: PlayResult
      var first = noHandle
      var second = noHandle
      var third = noHandle
      var activeCount = 0'u32
      var firstValidUnderLimit = false
      var secondValidAfterSteal = false
      var firstStop: PlayResult
      var secondStop: PlayResult
      var thirdStop: PlayResult
    act:
      configResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = minimumMaxActiveVoices))
      initResult = engine.init(initOptions(backend = nullBackend))
      first = engine.playSound(soundResult.sound)
      second = engine.playSound(soundResult.sound)
      third = engine.playSound(soundResult.sound)
      activeCount = engine.activeVoiceCount()
      firstValidUnderLimit = engine.isValid(first)
      secondValidAfterSteal = engine.isValid(second)
      firstStop = engine.stop(first)
      secondStop = engine.stop(second)
      thirdStop = engine.stop(third)
      soundResult.sound.dispose()
      engine.destroy()
    then:
      configResult.ok == true
      initResult.ok == true
      soundResult.ok == true
      first.isValid == true
      second.isValid == true
      third.isValid == true
      activeCount <= minimumMaxActiveVoices
      firstValidUnderLimit == true
      secondValidAfterSteal == true
      firstStop.ok == true
      secondStop.ok == true
      thirdStop.ok == true

  it "applies the same voice limit policy with NOSOUND backend":
    given:
      let engine = newEngine()
      var configResult: PlayResult
      var initResult: PlayResult
      var activeLimit = 0'u32
    act:
      configResult = engine.setVoiceOptions(voiceOptions(maxActiveVoices = minimumMaxActiveVoices))
      initResult = engine.init(initOptions(backend = noSoundBackend))
      activeLimit = engine.activeVoiceLimit()
      engine.destroy()
    then:
      configResult.ok == true
      initResult.ok == true
      activeLimit == minimumMaxActiveVoices
