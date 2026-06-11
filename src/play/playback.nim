## Nim-first public playback API.

import play/assets
import play/handles as engine_handles
import play/lifecycle as public_lifecycle
import play/types

export types

proc play*(sound: Sound, bus = defaultSoundBus): Handle =
  let engine = public_lifecycle.currentEngine()
  if engine == nil:
    return noHandle

  engine_handles.playSound(engine, sound, bus)

proc playMusic*(music: Music): Handle =
  let engine = public_lifecycle.currentEngine()
  if engine == nil:
    return noHandle

  engine_handles.playMusic(engine, music)
