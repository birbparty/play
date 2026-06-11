import bddy
import play

spec "top-level play API facade":
  it "exports the complete phase-1 public surface from import play":
    then:
      compiles(playVersion) == true

      compiles(PlayErrorKind) == true
      compiles(PlayError(kind: initFailed, message: "init")) == true
      compiles(PlayResult(ok: true)) == true
      compiles(PlayException) == true
      compiles(initFailed) == true
      compiles(unsupportedBackend) == true
      compiles(loadFailed) == true
      compiles(invalidAsset) == true
      compiles(invalidHandle) == true
      compiles(allocationFailed) == true
      compiles(playError(invalidHandle, "bad handle")) == true
      compiles(success()) == true
      compiles(failure(invalidHandleError("bad handle"))) == true
      compiles(raisePlayError(invalidHandleError("bad handle"))) == true
      compiles(raiseIfFailed(success())) == true
      compiles(initError("init", 1)) == true
      compiles(unsupportedBackendError("backend")) == true
      compiles(loadError("load")) == true
      compiles(invalidAssetError("asset")) == true
      compiles(invalidHandleError("handle")) == true
      compiles(allocationError("allocation")) == true

      compiles(Backend) == true
      compiles(InitFlag) == true
      compiles(InitFlags) == true
      compiles(InitOptions) == true
      compiles(clipRoundoff) == true
      compiles(enableVisualization) == true
      compiles(leftHanded3d) == true
      compiles(noFpuRegisterChange) == true
      compiles(defaultBackend) == true
      compiles(noSoundBackend) == true
      compiles(nullBackend) == true
      compiles(defaultBackend == nullBackend) == true
      compiles(initOptions(backend = nullBackend).backend) == true
      compiles(initOptions(flags = {enableVisualization}).flags) == true
      compiles(initOptions(sampleRate = 44100'u32).sampleRate) == true
      compiles(initOptions(bufferSize = 256'u32).bufferSize) == true
      compiles(initOptions(channels = 1'u32).channels) == true
      compiles(LifecycleState) == true
      compiles(lifecycleStopped) == true
      compiles(lifecycleRunning) == true
      compiles(lifecycleState()) == true
      compiles(activeBackend()) == true
      compiles(init(initOptions(backend = nullBackend))) == true
      compiles(shutdown()) == true
      compiles(withPlay(initOptions(backend = nullBackend), proc () = discard)) == true

      compiles(Sound) == true
      compiles(Music) == true
      compiles(loadSound("")) == true
      compiles(loadMusic("")) == true
      compiles(SoundResult()) == true
      compiles(MusicResult()) == true
      compiles(dispose(Sound(nil))) == true
      compiles(dispose(Music(nil))) == true
      compiles(isDisposed(Sound(nil))) == true
      compiles(isDisposed(Music(nil))) == true

      compiles(Handle) == true
      compiles(noHandle) == true
      compiles(noHandle.isValid) == true
      compiles(noHandle == noHandle) == true
      compiles($noHandle) == true
      compiles(pause(noHandle)) == true
      compiles(resume(noHandle)) == true
      compiles(stop(noHandle)) == true
      compiles(setLooping(noHandle, true)) == true
      compiles(setVolume(noHandle, 1.0'f32)) == true

      compiles(Bus) == true
      compiles(musicBus) == true
      compiles(sfxBus) == true
      compiles(uiBus) == true
      compiles(defaultSoundBus) == true
      compiles(musicBus.isValid) == true
      compiles(musicBus == defaultSoundBus) == true
      compiles(play(Sound(nil))) == true
      compiles(play(Sound(nil), uiBus)) == true
      compiles(playMusic(Music(nil))) == true
      compiles(setMasterVolume(1.0'f32)) == true
      compiles(setMusicVolume(1.0'f32)) == true
      compiles(setSfxVolume(1.0'f32)) == true
      compiles(setUiVolume(1.0'f32)) == true

      compiles(fadeVolume(noHandle, 0.0'f32, 0.001)) == true
      compiles(fadeInMusic(Music(nil), 0.001)) == true
      compiles(fadeOutMusic(noHandle, 0.001)) == true

  it "keeps raw bindings and explicit-engine wrapper internals out of import play":
    then:
      compiles(newEngine()) == false
      compiles(currentEngine()) == false
      compiles(rawHandle(nil)) == false
      compiles(rawBus(nil, musicBus)) == false
      compiles(rawBusHandle(nil, musicBus)) == false
      compiles(rawBackendId(defaultBackend)) == false
      compiles(rawInitFlags({clipRoundoff})) == false
      compiles(rawInitArgs(initOptions())) == false
      compiles(audioSource(Sound(nil))) == false
      compiles(rawVoiceHandle(noHandle)) == false
      compiles(handleFromRaw(1'u32)) == false
      compiles(pause(currentEngine(), noHandle)) == false
      compiles(setMusicVolume(currentEngine(), 1.0'f32)) == false
      compiles(fadeVolume(currentEngine(), noHandle, 0.0'f32, 0.001)) == false
      compiles(Bus_create()) == false
      compiles(Wav_create()) == false
      compiles(Soloud_create()) == false
