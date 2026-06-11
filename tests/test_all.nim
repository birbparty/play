import std/strutils

import bddy
import play
import common/test_helpers

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
      let wavPath = fixturePath("generated", "tone.wav").replace("\\", "/")
    verify:
      wavPath.endsWith("tests/fixtures/generated/tone.wav")
