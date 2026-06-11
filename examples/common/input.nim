## Small input helpers shared by interactive examples.

type ExampleAction* = enum
  noAction
  playSfx
  toggleMusic
  fadeMusic
  quitExample

proc actionForKey*(key: char): ExampleAction =
  case key
  of 's', 'S', ' ':
    playSfx
  of 'm', 'M':
    toggleMusic
  of 'f', 'F':
    fadeMusic
  of 'q', 'Q', '\e':
    quitExample
  else:
    noAction

proc shouldQuit*(key: char): bool =
  actionForKey(key) == quitExample
