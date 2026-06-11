import play/soloud

let sound = Sound()
let music = Music()

when compiles(sound.handle):
  {.error: "Sound.handle must not be public".}

when compiles(music.handle):
  {.error: "Music.handle must not be public".}

when compiles(audioSource(sound)):
  {.error: "private asset audioSource bridge must not be public".}

when compiles(rawHandle(newEngine())):
  {.error: "private engine rawHandle bridge must not be public".}

when compiles(Wav):
  {.error: "raw Wav type must not be exported by play/soloud".}

when compiles(WavStream):
  {.error: "raw WavStream type must not be exported by play/soloud".}

when compiles(AudioSource):
  {.error: "raw AudioSource type must not be exported by play/soloud".}
