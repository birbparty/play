import bddy
import bus_volume_demo

spec "bus volume demo example":
  it "runs headlessly and exercises fixed buses":
    given:
      var config = defaultBusDemoConfig()
      var result = BusDemoResult()
    act:
      config.holdMs = 0
      result = runBusVolumeDemo(config)
    then:
      result.ok == true
      result.volumesChanged == true
      result.musicPlayed == true
      result.sfxPlayed == true
      result.uiPlayed == true
