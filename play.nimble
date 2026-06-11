# Package

version       = "0.1.0"
author        = "birbparty"
description   = "Nim audio library for games built on SoLoud"
license       = "Zlib"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task test, "Run the play test suite":
  exec "nim c -r tests/test_all.nim"
