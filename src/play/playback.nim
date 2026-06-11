## Nim-first public playback API.

import play/assets
import play/private/global_engine
import play/private/handles as engine_handles
import play/types

export types

proc play*(sound: Sound, bus = defaultSoundBus): Handle =
  let engine = currentEngine()
  if engine == nil:
    return noHandle

  engine_handles.playSound(engine, sound, bus)

proc playMusic*(music: Music): Handle =
  let engine = currentEngine()
  if engine == nil:
    return noHandle

  engine_handles.playMusic(engine, music)
