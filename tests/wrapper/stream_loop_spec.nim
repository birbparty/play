import std/os

import bddy
import common/test_helpers
import play

# Regression smoke for the WavStreamInstance::seek union-dispatch defect
# (play-vto): a looping streamed WAV crossing its end dispatched into
# stb_vorbis with a drwav pointer. The NOSOUND backend mixes in real time on
# its own thread, so holding a looping short WAV past its duration exercises
# the loop-restart seek path. The undefined behavior faulted on 3DS hardware
# and may not fault on every host, so this is a smoke check, not a proof.
spec "streamed source looping":
  it "loops a streamed WAV across its end without faulting":
    given:
      var initResult = PlayResult()
      var music = MusicResult()
      var handle = noHandle
      var playedValid = false
      var stillPlaying = false
    act:
      initResult = init(initOptions(backend = noSoundBackend))
      music = loadMusic(fixturePath("generated", "tone_sfx.wav"))
      handle = playMusic(music.music)
      playedValid = handle.isValid
      discard setLooping(handle, true)
      sleep(600)
      stillPlaying = handle.isValid
      discard stop(handle)
      music.music.dispose()
      shutdown()
    then:
      initResult.ok == true
      music.ok == true
      playedValid == true
      stillPlaying == true
