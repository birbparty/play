import bddy
import play

spec "public audio types":
  it "exports opaque asset types from the top-level play import":
    given:
      var sound: Sound
      var music: Music
    then:
      sound.isDisposed == true
      music.isDisposed == true
      compiles(sound.handle) == false
      compiles(music.handle) == false

  it "provides cheap opaque handle validity checks":
    given:
      let empty = noHandle
      var copied = empty
    then:
      empty.isValid == false
      copied == empty
      $empty == "Handle(0)"
      compiles(Handle(123'u32)) == false
      compiles(uint32(empty)) == false
      compiles(empty.id) == false
      compiles(rawVoiceHandle(empty)) == false
      compiles(handleFromRaw(1'u32)) == false

  it "defines fixed public bus values without exposing raw bus handles":
    then:
      defaultSoundBus == sfxBus
      musicBus.isValid == true
      musicBus != sfxBus
      sfxBus != uiBus
      compiles(Bus(1'u8)) == false
      compiles(musicBus.id) == false
      compiles(rawBackendId(defaultBackend)) == false
      compiles(Bus_create()) == false
