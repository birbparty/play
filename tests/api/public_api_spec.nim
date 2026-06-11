import bddy
import play

spec "top-level play API facade":
  it "exports the complete phase-1 public surface from import play":
    then:
      compiles(playVersion) == true

      compiles(PlayResult(ok: true)) == true
      compiles(playError(invalidHandle, "bad handle")) == true
      compiles(success()) == true
      compiles(failure(invalidHandleError("bad handle"))) == true
      compiles(raiseIfFailed(success())) == true

      compiles(defaultBackend) == true
      compiles(noSoundBackend) == true
      compiles(nullBackend) == true
      compiles(initOptions(backend = nullBackend)) == true
      compiles(lifecycleState()) == true
      compiles(activeBackend()) == true
      compiles(init(initOptions(backend = nullBackend))) == true
      compiles(shutdown()) == true
      compiles(withPlay(initOptions(backend = nullBackend), proc () = discard)) == true

      compiles(loadSound("")) == true
      compiles(loadMusic("")) == true
      compiles(SoundResult()) == true
      compiles(MusicResult()) == true

      compiles(noHandle) == true
      compiles(noHandle.isValid) == true
      compiles(pause(noHandle)) == true
      compiles(resume(noHandle)) == true
      compiles(stop(noHandle)) == true
      compiles(setLooping(noHandle, true)) == true
      compiles(setVolume(noHandle, 1.0'f32)) == true

      compiles(musicBus) == true
      compiles(sfxBus) == true
      compiles(uiBus) == true
      compiles(defaultSoundBus) == true
      compiles(musicBus.isValid) == true
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
