import std/strutils

import bddy
import play
import common/test_helpers
{.warning[UnusedImport]: off.}
import wrapper/errors_spec
import wrapper/lifecycle_spec
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
