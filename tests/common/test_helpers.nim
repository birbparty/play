## Shared helpers for play's bddy test binaries.

import std/os

const fixtureRoot* = currentSourcePath().parentDir.parentDir / "fixtures"

proc fixturePath*(parts: varargs[string]): string =
  result = fixtureRoot
  for part in parts:
    result = result / part

proc fixtureExists*(parts: varargs[string]): bool =
  fileExists(fixturePath(parts))
