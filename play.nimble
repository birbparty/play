# Package

version       = "0.1.0"
author        = "birbparty"
description   = "Nim audio library for games built on SoLoud"
license       = "Zlib"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Pinned test framework. This follows the clckr convention of URL-pinning fork
# dependencies by commit SHA while the birbparty ecosystem packages are still in
# active platform-port work.
requires "https://github.com/mattsp1290/bddy#34287484337fbad6626525062fe27d28fcb0fc58"

# Tasks

task test, "Run the play test suite":
  exec "nim c --path:src -r tests/test_all.nim"
