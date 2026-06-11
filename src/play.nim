## Nim-first public API facade for play.
##
## Phase-1 implementation modules will be exported from here as their beads
## land. This file intentionally stays minimal until the lifecycle, asset,
## playback, handle, bus, and fade APIs are implemented.

import play/assets
import play/buses
import play/fades
import play/handles
import play/lifecycle
import play/playback
import play/types

export assets
export buses
export fades
export handles
export lifecycle
export playback
export types

const playVersion* = "0.1.0"
