import std/strutils

import bddy
import play
import common/test_helpers
{.warning[UnusedImport]: off.}
import api/assets_spec
import api/buses_spec
import api/fades_spec
import api/handles_spec
import api/lifecycle_spec
import api/playback_spec
import api/public_api_spec
import api/types_spec
import examples/bus_volume_demo_spec
import examples/example_assets_spec
import examples/music_fades_spec
import examples/sfx_keypress_spec
import fixtures/fixtures_spec
import stress/realtime_boundary_spec
import wrapper/assets_spec
import wrapper/buses_spec
import wrapper/errors_spec
import wrapper/fades_spec
import wrapper/handles_spec
import wrapper/lifecycle_spec
import wrapper/shutdown_stress_spec
import wrapper/voice_limits_spec
{.warning[UnusedImport]: on.}

spec "play package":
  it "exports package metadata via bddy":
    given:
      let version = playVersion
      var hasVersion = false
    act:
      hasVersion = version.len > 0
    then:
      hasVersion == true

  it "resolves the fixture root helper":
    given:
      let expectedSuffix = "tests/fixtures/generated/tone.wav"
      var wavPath = ""
    act:
      wavPath = fixturePath("generated", "tone.wav").replace("\\", "/")
    then:
      wavPath.endsWith(expectedSuffix)
