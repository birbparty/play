## Public opaque audio asset, voice handle, and bus types.

import play/assets
import play/private/types as privateTypes

export Sound, Music
export dispose, isDisposed
export privateTypes except handleFromRaw, rawVoiceHandle, isValid

type
  Bus* = object
    id: uint8

const
  musicBus* = Bus(id: 1'u8)
  sfxBus* = Bus(id: 2'u8)
  uiBus* = Bus(id: 3'u8)
  defaultSoundBus* = sfxBus

proc isValid*(bus: Bus): bool =
  bus.id != 0

proc `==`*(left, right: Bus): bool =
  left.id == right.id
