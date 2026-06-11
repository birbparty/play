## Process-global engine storage shared by public facade modules.

import play/private/lifecycle

var engine: Engine

proc currentEngine*(): Engine =
  engine

proc ensureEngine*(): Engine =
  if engine == nil:
    engine = newEngine()

  engine

proc clearEngine*() =
  if engine == nil:
    return

  engine.destroy()
  engine = nil
