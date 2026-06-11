import bddy
import common/test_helpers
import play
import play/bindings/soloud_raw as raw except Bus
import play/private/global_engine
import play/private/lifecycle as engine_lifecycle

proc busVoiceCount(bus: Bus): cuint =
  let engine = currentEngine()
  if engine == nil:
    return 0'u32

  let rawBus = engine_lifecycle.rawBus(engine, bus)
  if rawBus == nil:
    return 0'u32

  raw.Bus_getActiveVoiceCount(rawBus)

spec "public playback API":
  it "rejects playback before init":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var soundHandle = noHandle
      var musicHandle = noHandle
    act:
      soundHandle = play(soundResult.sound)
      musicHandle = playMusic(musicResult.music)
      soundResult.sound.dispose()
      musicResult.music.dispose()
    then:
      soundResult.ok == true
      musicResult.ok == true
      soundHandle == noHandle
      musicHandle == noHandle

  it "starts SFX playback on the default sfx bus":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var musicVoices = 0'u32
      var sfxVoices = 0'u32
      var uiVoices = 0'u32
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = play(soundResult.sound)
      musicVoices = busVoiceCount(musicBus)
      sfxVoices = busVoiceCount(sfxBus)
      uiVoices = busVoiceCount(uiBus)
      soundResult.sound.dispose()
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      handle.isValid == true
      musicVoices == 0'u32
      sfxVoices == 1'u32
      uiVoices == 0'u32

  it "starts SFX playback on an explicit public bus":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      var initResult: PlayResult
      var handle = noHandle
      var musicVoices = 0'u32
      var sfxVoices = 0'u32
      var uiVoices = 0'u32
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = play(soundResult.sound, uiBus)
      musicVoices = busVoiceCount(musicBus)
      sfxVoices = busVoiceCount(sfxBus)
      uiVoices = busVoiceCount(uiBus)
      soundResult.sound.dispose()
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      handle.isValid == true
      musicVoices == 0'u32
      sfxVoices == 0'u32
      uiVoices == 1'u32

  it "starts streamed music playback on the music bus":
    given:
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      var initResult: PlayResult
      var handle = noHandle
      var musicVoices = 0'u32
      var sfxVoices = 0'u32
      var uiVoices = 0'u32
    act:
      initResult = init(initOptions(backend = nullBackend))
      handle = playMusic(musicResult.music)
      musicVoices = busVoiceCount(musicBus)
      sfxVoices = busVoiceCount(sfxBus)
      uiVoices = busVoiceCount(uiBus)
      musicResult.music.dispose()
      shutdown()
    then:
      initResult.ok == true
      musicResult.ok == true
      handle.isValid == true
      musicVoices == 1'u32
      sfxVoices == 0'u32
      uiVoices == 0'u32

  it "rejects playback from disposed or failed assets":
    given:
      let soundResult = loadSound(fixturePath("generated", "tone_sfx.wav"))
      let musicResult = loadMusic(fixturePath("generated", "tone_music.ogg"))
      let failedSound = loadSound(fixturePath("generated", "missing-sfx.wav"))
      let failedMusic = loadMusic(fixturePath("generated", "missing-music.ogg"))
      var initResult: PlayResult
      var disposedSoundHandle = noHandle
      var disposedMusicHandle = noHandle
      var failedSoundHandle = noHandle
      var failedMusicHandle = noHandle
    act:
      initResult = init(initOptions(backend = nullBackend))
      soundResult.sound.dispose()
      musicResult.music.dispose()
      disposedSoundHandle = play(soundResult.sound)
      disposedMusicHandle = playMusic(musicResult.music)
      failedSoundHandle = play(failedSound.sound)
      failedMusicHandle = playMusic(failedMusic.music)
      shutdown()
    then:
      initResult.ok == true
      soundResult.ok == true
      musicResult.ok == true
      failedSound.ok == false
      failedMusic.ok == false
      disposedSoundHandle == noHandle
      disposedMusicHandle == noHandle
      failedSoundHandle == noHandle
      failedMusicHandle == noHandle
