# Package
#
# Nimble derives the package name `play` from this manifest filename.

version       = "0.1.0"
author        = "birbparty"
description   = "Nim audio library for games built on SoLoud"
license       = "Zlib"
srcDir        = "."
installFiles  = @["play.nim"]
installDirs   = @["play", "vendor"]

# Dependencies

requires "nim >= 2.0.0"

# Pinned test framework. This follows the clckr convention of URL-pinning fork
# dependencies by commit SHA while the birbparty ecosystem packages are still in
# active platform-port work.
requires "https://github.com/mattsp1290/bddy#34287484337fbad6626525062fe27d28fcb0fc58"

# Tasks

task test, "Run the play test suite":
  # Keep this task as the aggregation point as future beads add bddy binaries.
  exec "sh tests/consumer/verify_consumer.sh"
  exec "nim c --path:src --path:examples examples/phase1_public_api.nim"
  exec "nim c --path:src --path:examples -r examples/bus_volume_demo.nim --quiet"
  exec "nim c --path:src --path:examples -r examples/music_fades.nim --quiet"
  exec "nim c --path:src --path:examples -r examples/sfx_keypress.nim --keys=sq --quiet"
  exec "sh scripts/build_desktop_examples.sh --smoke"
  exec "nim c --path:src --path:examples --path:tests -r tests/examples/test_example_assets.nim"
  exec "nim c --path:src --path:examples --path:tests -r tests/examples/test_bus_volume_demo.nim"
  exec "nim c --path:src --path:examples --path:tests -r tests/examples/test_music_fades.nim"
  exec "nim c --path:src --path:examples --path:tests -r tests/examples/test_sfx_keypress.nim"
  exec "nim c --path:src tests/test_soloud_compile.nim"
  exec "nim c --path:src -r tests/bindings/test_soloud_raw.nim"
  exec "nim check --path:src -d:playPlatformVita tests/bindings/test_soloud_raw.nim"
  exec "nim check --path:src -d:playPlatform3ds tests/bindings/test_soloud_raw.nim"
  exec "nim c --path:src -r tests/bindings/test_backends.nim"
  exec "nim check --path:src -d:playPlatformVita tests/bindings/test_backends.nim"
  exec "nim check --path:src -d:playPlatform3ds tests/bindings/test_backends.nim"
  exec "nim c --path:src -r tests/wrapper/test_lifecycle.nim"
  exec "nim c --path:src -r tests/wrapper/test_errors.nim"
  exec "nim c --path:src --path:tests -r tests/wrapper/test_assets.nim"
  exec "nim c --path:src --path:tests -r tests/wrapper/test_buses.nim"
  exec "nim c --path:src --path:tests -r tests/wrapper/test_fades.nim"
  exec "nim c --path:src --path:tests -r tests/wrapper/test_handles.nim"
  exec "nim c --path:src --path:tests -r tests/wrapper/test_shutdown_stress.nim"
  exec "nim c --path:src --path:tests -r tests/wrapper/test_voice_limits.nim"
  exec "nim check --path:src tests/wrapper/assets_api_boundary.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_assets.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_buses.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_fades.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_handles.nim"
  exec "nim c --path:src -r tests/api/test_lifecycle.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_playback.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_public_api.nim"
  exec "nim c --path:src --path:tests -r tests/api/test_types.nim"
  exec "nim c --path:src --path:tests -r tests/fixtures/test_fixtures.nim"
  exec "nim c --path:src --path:examples --path:tests -r tests/test_all.nim"

task testTap, "Run the play test suite with TAP output":
  exec "nim c --path:src tests/test_soloud_compile.nim"
  exec "nim c --path:src -r tests/bindings/test_soloud_raw.nim"
  exec "nim check --path:src -d:playPlatformVita tests/bindings/test_soloud_raw.nim"
  exec "nim check --path:src -d:playPlatform3ds tests/bindings/test_soloud_raw.nim"
  exec "nim c --path:src -r tests/bindings/test_backends.nim"
  exec "nim check --path:src -d:playPlatformVita tests/bindings/test_backends.nim"
  exec "nim check --path:src -d:playPlatform3ds tests/bindings/test_backends.nim"
  exec "nim c --path:src --path:examples --path:tests -d:bddyTap -r tests/test_all.nim"

task testJunit, "Run the play test suite with JUnit output":
  mkDir "tests/results"
  exec "nim c --path:src tests/test_soloud_compile.nim"
  exec "nim c --path:src -r tests/bindings/test_soloud_raw.nim"
  exec "nim check --path:src -d:playPlatformVita tests/bindings/test_soloud_raw.nim"
  exec "nim check --path:src -d:playPlatform3ds tests/bindings/test_soloud_raw.nim"
  exec "nim c --path:src -r tests/bindings/test_backends.nim"
  exec "nim check --path:src -d:playPlatformVita tests/bindings/test_backends.nim"
  exec "nim check --path:src -d:playPlatform3ds tests/bindings/test_backends.nim"
  # bddyJunit is a strdefine; keep the path in the same quoted compiler argument.
  exec "nim c --path:src --path:examples --path:tests \"-d:bddyJunit:tests/results/test_all.xml\" -r tests/test_all.nim"
