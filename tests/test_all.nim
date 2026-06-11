import bddy
import play

spec "play package":
  it "exports package metadata":
    verify:
      playVersion.len > 0
