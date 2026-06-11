## Nim-first public fade helpers.
##
## Fade timers advance when SoLoud mixes audio. In tests or manual pump loops
## using NULLDRIVER/NOSOUND, allow time to pass and pump/mix before asserting
## the final volume or stop state.

import play/assets
import play/errors
import play/private/fades as engine_fades
import play/private/global_engine
import play/types

export types

proc fadeVolume*(handle: Handle, target: float32, seconds: float64): PlayResult =
  engine_fades.fadeVolume(currentEngine(), handle, target, seconds)

proc fadeInMusic*(music: Music, seconds: float64, target = 1.0'f32): Handle =
  engine_fades.fadeInMusic(currentEngine(), music, seconds, target)

proc fadeOutMusic*(handle: Handle, seconds: float64): PlayResult =
  engine_fades.fadeOutMusic(currentEngine(), handle, seconds)
