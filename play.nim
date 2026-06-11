## Nim-first public API facade for play.
##
## Importing `play` exposes the phase-1 lifecycle, asset, playback, handle,
## bus, and fade APIs without requiring callers to import the SoLoud wrapper
## or raw binding modules.

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
