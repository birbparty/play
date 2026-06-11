import std/strutils

import bddy
import common/test_helpers
import play

spec "public asset loading API":
  it "loads and disposes public sound assets from the top-level play import":
    given:
      let wavPath = fixturePath("generated", "tone_sfx.wav")
      let oggPath = fixturePath("generated", "tone_music.ogg")
      var wav: SoundResult
      var ogg: SoundResult
    act:
      wav = loadSound(wavPath)
      ogg = loadSound(oggPath)
      wav.sound.dispose()
      ogg.sound.dispose()
    then:
      wav.ok == true
      wav.sound.isDisposed == true
      ogg.ok == true
      ogg.sound.isDisposed == true

  it "loads and disposes public streamed music assets":
    given:
      let wavPath = fixturePath("generated", "tone_music.wav")
      let oggPath = fixturePath("generated", "tone_music_long.ogg")
      var wav: MusicResult
      var ogg: MusicResult
    act:
      wav = loadMusic(wavPath)
      ogg = loadMusic(oggPath)
      wav.music.dispose()
      ogg.music.dispose()
    then:
      wav.ok == true
      wav.music.isDisposed == true
      ogg.ok == true
      ogg.music.isDisposed == true

  it "reports missing and invalid assets through public error results":
    given:
      let missingSound = fixturePath("generated", "missing-sound.wav")
      let missingMusic = fixturePath("generated", "missing-music.ogg")
      let invalid = fixturePath("generated", "README.md")
      var soundMissing: SoundResult
      var musicMissing: MusicResult
      var soundInvalid: SoundResult
      var musicInvalid: MusicResult
    act:
      soundMissing = loadSound(missingSound)
      musicMissing = loadMusic(missingMusic)
      soundInvalid = loadSound(invalid)
      musicInvalid = loadMusic(invalid)
    then:
      soundMissing.ok == false
      soundMissing.error.kind == loadFailed
      soundMissing.error.message.contains("does not exist")
      musicMissing.ok == false
      musicMissing.error.kind == loadFailed
      musicMissing.error.message.contains("does not exist")
      soundInvalid.ok == false
      soundInvalid.error.kind == loadFailed
      soundInvalid.error.code != 0
      musicInvalid.ok == false
      musicInvalid.error.kind == loadFailed
      musicInvalid.error.code != 0

  it "keeps raw asset handles hidden while exposing result types":
    given:
      let soundResult = SoundResult()
      let musicResult = MusicResult()
    then:
      soundResult.ok == false
      musicResult.ok == false
      compiles(soundResult.sound.handle) == false
      compiles(musicResult.music.handle) == false
      compiles(audioSource(soundResult.sound)) == false
      compiles(Wav_create()) == false
