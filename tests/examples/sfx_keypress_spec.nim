import bddy
import sfx_keypress

spec "sfx keypress demo example":
  it "runs headlessly and plays WAV SFX for key input":
    given:
      var config = defaultSfxKeypressConfig()
      var result = SfxKeypressResult()
    act:
      config.keys = "sx q"
      config.holdMs = 0
      result = runSfxKeypressDemo(config)
    then:
      result.ok == true
      result.initialized == true
      result.soundLoaded == true
      result.playedCount == 2
      result.quitRequested == true
