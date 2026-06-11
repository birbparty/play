import bddy
import common/test_helpers
import play/bindings/soloud_raw as raw
import play/private/lifecycle as privateLifecycle
import play/soloud
import play/types as publicTypes

proc activeBusVolume(engine: privateLifecycle.Engine, bus: publicTypes.Bus): float32 =
  let soloud = engine.rawHandle()
  let handle = engine.rawBusHandle(bus)
  if soloud == nil or handle == 0'u32:
    return -1.0'f32

  float32(raw.Soloud_getVolume(soloud, handle))

spec "SoLoud fixed bus routing":
  it "initializes fixed buses once and applies bus volumes":
    given:
      let engine = newEngine()
      var firstInit: PlayResult
      var secondInit: PlayResult
      var masterVolume: PlayResult
      var musicVolume: PlayResult
      var sfxVolume: PlayResult
      var uiVolume: PlayResult
    act:
      firstInit = engine.init(initOptions(backend = nullBackend))
      secondInit = engine.init(initOptions(backend = nullBackend))
      masterVolume = engine.setMasterVolume(0.75'f32)
      musicVolume = engine.setMusicVolume(0.5'f32)
      sfxVolume = engine.setSfxVolume(0.25'f32)
      uiVolume = engine.setUiVolume(0.9'f32)
      engine.destroy()
    then:
      firstInit.ok == true
      secondInit.ok == true
      masterVolume.ok == true
      musicVolume.ok == true
      sfxVolume.ok == true
      uiVolume.ok == true

  it "applies fixed bus volume to active bus voice handles":
    given:
      let engine = newEngine()
      var initResult: PlayResult
      var musicVolume: PlayResult
      var sfxVolume: PlayResult
      var uiVolume: PlayResult
      var musicActiveVolume = 0.0'f32
      var sfxActiveVolume = 0.0'f32
      var uiActiveVolume = 0.0'f32
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      musicVolume = engine.setMusicVolume(0.125'f32)
      sfxVolume = engine.setSfxVolume(0.25'f32)
      uiVolume = engine.setUiVolume(0.5'f32)
      musicActiveVolume = engine.activeBusVolume(musicBus)
      sfxActiveVolume = engine.activeBusVolume(sfxBus)
      uiActiveVolume = engine.activeBusVolume(uiBus)
      engine.destroy()
    then:
      initResult.ok == true
      musicVolume.ok == true
      sfxVolume.ok == true
      uiVolume.ok == true
      musicActiveVolume == 0.125'f32
      sfxActiveVolume == 0.25'f32
      uiActiveVolume == 0.5'f32

  it "routes sounds to sfx by default and selected fixed buses explicitly":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var defaultHandle = noHandle
      var uiHandle = noHandle
      var musicHandle = noHandle
      var defaultValid = false
      var uiValid = false
      var musicValid = false
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      defaultHandle = engine.playSound(soundResult.sound)
      uiHandle = engine.playSound(soundResult.sound, uiBus)
      musicHandle = engine.playSound(soundResult.sound, musicBus)
      defaultValid = engine.isValid(defaultHandle)
      uiValid = engine.isValid(uiHandle)
      musicValid = engine.isValid(musicHandle)
      soundResult.sound.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      soundResult.ok == true
      defaultHandle.isValid == true
      uiHandle.isValid == true
      musicHandle.isValid == true
      defaultValid == true
      uiValid == true
      musicValid == true

  it "routes streamed music through the music bus":
    given:
      let engine = newEngine()
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var valid = false
      var stopped: PlayResult
    act:
      initResult = engine.init(initOptions(backend = nullBackend))
      handle = engine.playMusic(musicResult.music)
      valid = engine.isValid(handle)
      stopped = engine.stop(handle)
      musicResult.music.dispose()
      engine.destroy()
    then:
      initResult.ok == true
      musicResult.ok == true
      handle.isValid == true
      valid == true
      stopped.ok == true

  it "rejects bus volume changes before engine initialization":
    given:
      let engine = newEngine()
      var masterVolume: PlayResult
      var musicVolume: PlayResult
      var sfxVolume: PlayResult
      var uiVolume: PlayResult
    act:
      masterVolume = engine.setMasterVolume(1.0'f32)
      musicVolume = engine.setMusicVolume(1.0'f32)
      sfxVolume = engine.setSfxVolume(1.0'f32)
      uiVolume = engine.setUiVolume(1.0'f32)
      engine.destroy()
    then:
      masterVolume.ok == false
      masterVolume.error.kind == invalidHandle
      musicVolume.ok == false
      musicVolume.error.kind == invalidHandle
      sfxVolume.ok == false
      sfxVolume.error.kind == invalidHandle
      uiVolume.ok == false
      uiVolume.error.kind == invalidHandle

  it "recreates fixed buses after shutdown and reinit":
    given:
      let engine = newEngine()
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var firstInit: PlayResult
      var secondInit: PlayResult
      var handle = noHandle
      var valid = false
      var uiVolume: PlayResult
    act:
      firstInit = engine.init(initOptions(backend = nullBackend))
      engine.shutdown()
      secondInit = engine.init(initOptions(backend = nullBackend))
      uiVolume = engine.setUiVolume(0.5'f32)
      handle = engine.playSound(soundResult.sound, uiBus)
      valid = engine.isValid(handle)
      soundResult.sound.dispose()
      engine.destroy()
    then:
      firstInit.ok == true
      secondInit.ok == true
      soundResult.ok == true
      uiVolume.ok == true
      handle.isValid == true
      valid == true
