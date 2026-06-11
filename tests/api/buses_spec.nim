import bddy
import play
import play/bindings/soloud_raw as raw except Bus, Bus_create, Bus_destroy
import play/private/global_engine
import play/private/lifecycle as engine_lifecycle

proc activeBusVolume(bus: Bus): float32 =
  let engine = currentEngine()
  if engine == nil:
    return -1.0'f32

  let soloud = engine.rawHandle()
  let handle = engine.rawBusHandle(bus)
  if soloud == nil or handle == 0'u32:
    return -1.0'f32

  float32(raw.Soloud_getVolume(soloud, handle))

proc activeMasterVolume(): float32 =
  let engine = currentEngine()
  if engine == nil:
    return -1.0'f32

  let soloud = engine.rawHandle()
  if soloud == nil:
    return -1.0'f32

  float32(raw.Soloud_getGlobalVolume(soloud))

spec "public fixed bus volume API":
  it "rejects volume changes before init":
    given:
      var masterVolume: PlayResult
      var musicVolume: PlayResult
      var sfxVolume: PlayResult
      var uiVolume: PlayResult
    act:
      masterVolume = setMasterVolume(1.0'f32)
      musicVolume = setMusicVolume(1.0'f32)
      sfxVolume = setSfxVolume(1.0'f32)
      uiVolume = setUiVolume(1.0'f32)
    then:
      masterVolume.ok == false
      masterVolume.error.kind == invalidHandle
      musicVolume.ok == false
      musicVolume.error.kind == invalidHandle
      sfxVolume.ok == false
      sfxVolume.error.kind == invalidHandle
      uiVolume.ok == false
      uiVolume.error.kind == invalidHandle

  it "applies master and fixed bus volumes through the top-level facade":
    given:
      var initResult: PlayResult
      var masterVolume: PlayResult
      var musicVolume: PlayResult
      var sfxVolume: PlayResult
      var uiVolume: PlayResult
      var activeMaster = 0.0'f32
      var activeMusic = 0.0'f32
      var activeSfx = 0.0'f32
      var activeUi = 0.0'f32
    act:
      initResult = init(initOptions(backend = nullBackend))
      masterVolume = setMasterVolume(0.75'f32)
      musicVolume = setMusicVolume(0.125'f32)
      sfxVolume = setSfxVolume(0.25'f32)
      uiVolume = setUiVolume(0.5'f32)
      activeMaster = activeMasterVolume()
      activeMusic = activeBusVolume(musicBus)
      activeSfx = activeBusVolume(sfxBus)
      activeUi = activeBusVolume(uiBus)
      shutdown()
    then:
      initResult.ok == true
      masterVolume.ok == true
      musicVolume.ok == true
      sfxVolume.ok == true
      uiVolume.ok == true
      activeMaster == 0.75'f32
      activeMusic == 0.125'f32
      activeSfx == 0.25'f32
      activeUi == 0.5'f32

  it "applies public bus volume controls with NOSOUND backend":
    given:
      var initResult: PlayResult
      var masterVolume: PlayResult
      var musicVolume: PlayResult
      var sfxVolume: PlayResult
      var uiVolume: PlayResult
    act:
      initResult = init(initOptions(backend = noSoundBackend))
      masterVolume = setMasterVolume(0.75'f32)
      musicVolume = setMusicVolume(0.125'f32)
      sfxVolume = setSfxVolume(0.25'f32)
      uiVolume = setUiVolume(0.5'f32)
      shutdown()
    then:
      initResult.ok == true
      masterVolume.ok == true
      musicVolume.ok == true
      sfxVolume.ok == true
      uiVolume.ok == true

  it "keeps bus creation and raw bus access out of the public API":
    then:
      musicBus.isValid == true
      sfxBus.isValid == true
      uiBus.isValid == true
      defaultSoundBus == sfxBus
      compiles(Bus_create()) == false
      compiles(Bus_destroy(nil)) == false
      compiles(setMusicVolume(currentEngine(), 1.0'f32)) == false
