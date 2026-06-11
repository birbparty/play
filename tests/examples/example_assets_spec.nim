import std/[os, strutils]

import bddy
import common/assets
import common/input
import play

spec "shared example utilities":
  it "resolves example audio assets from the repository":
    given:
      let sfx = exampleAssetPath(clickSfx)
      let music = exampleAssetPath(themeMusic)
      let longMusic = exampleAssetPath(longThemeMusic)
    then:
      fileExists(sfx) == true
      fileExists(music) == true
      fileExists(longMusic) == true
      sfx.endsWith("tone_sfx.wav") == true
      music.endsWith("tone_music.ogg") == true
      longMusic.endsWith("tone_music_long.ogg") == true

  it "loads shared example assets through the public API":
    given:
      var sound: SoundResult
      var music: MusicResult
    act:
      sound = loadExampleSound(clickSfx)
      music = loadExampleMusic(themeMusic)
      sound.sound.dispose()
      music.music.dispose()
    then:
      sound.ok == true
      music.ok == true
      sound.sound.isDisposed == true
      music.music.isDisposed == true

  it "maps simple example input keys to actions":
    then:
      actionForKey('s') == playSfx
      actionForKey('M') == toggleMusic
      actionForKey('f') == fadeMusic
      shouldQuit('q') == true
      actionForKey('x') == noAction
