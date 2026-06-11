## Nim-first public fixed bus volume controls.

import play/errors
import play/private/buses as engine_buses
import play/private/global_engine
import play/types

export types

proc setMasterVolume*(volume: float32): PlayResult =
  engine_buses.setMasterVolume(currentEngine(), volume)

proc setMusicVolume*(volume: float32): PlayResult =
  engine_buses.setMusicVolume(currentEngine(), volume)

proc setSfxVolume*(volume: float32): PlayResult =
  engine_buses.setSfxVolume(currentEngine(), volume)

proc setUiVolume*(volume: float32): PlayResult =
  engine_buses.setUiVolume(currentEngine(), volume)
