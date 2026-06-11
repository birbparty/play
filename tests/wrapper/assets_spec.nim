import std/strutils

import bddy
import common/test_helpers
import play/soloud

spec "SoLoud asset wrappers":
  it "loads and disposes resident WAV sound assets deterministically":
    given:
      let path = fixturePath("generated", "tone_sfx.wav")
      var loaded: SoundResult
      var sound: Sound
    act:
      loaded = loadSound(path)
      sound = loaded.sound
      sound.dispose()
      sound.dispose()
    then:
      loaded.ok == true
      sound.isDisposed == true

  it "loads resident OGG sound assets":
    given:
      let path = fixturePath("generated", "tone_music.ogg")
      var loaded: SoundResult
    act:
      loaded = loadSound(path)
      loaded.sound.dispose()
    then:
      loaded.ok == true

  it "loads streamed WAV and OGG music assets without taking ownership of file bytes":
    given:
      let wavPath = fixturePath("generated", "tone_music.wav")
      let oggPath = fixturePath("generated", "tone_music_long.ogg")
      var wavMusic: MusicResult
      var oggMusic: MusicResult
    act:
      wavMusic = loadMusic(wavPath)
      oggMusic = loadMusic(oggPath)
      wavMusic.music.dispose()
      oggMusic.music.dispose()
    then:
      wavMusic.ok == true
      wavMusic.music.isDisposed == true
      oggMusic.ok == true
      oggMusic.music.isDisposed == true

  it "rejects missing and invalid sound assets without leaving live wrappers":
    given:
      let missing = fixturePath("generated", "does-not-exist.wav")
      let invalid = fixturePath("generated", "README.md")
      var missingResult: SoundResult
      var invalidResult: SoundResult
    act:
      missingResult = loadSound(missing)
      invalidResult = loadSound(invalid)
    then:
      missingResult.ok == false
      missingResult.error.kind == loadFailed
      missingResult.error.message.contains("does not exist")
      invalidResult.ok == false
      invalidResult.error.kind == loadFailed
      invalidResult.error.code != 0
      invalidResult.sound.isDisposed == true

  it "rejects missing and invalid music assets without leaving live wrappers":
    given:
      let missing = fixturePath("generated", "does-not-exist.ogg")
      let invalid = fixturePath("generated", "README.md")
      var missingResult: MusicResult
      var invalidResult: MusicResult
    act:
      missingResult = loadMusic(missing)
      invalidResult = loadMusic(invalid)
    then:
      missingResult.ok == false
      missingResult.error.kind == loadFailed
      invalidResult.ok == false
      invalidResult.error.kind == loadFailed
      invalidResult.error.code != 0
      invalidResult.music.isDisposed == true
