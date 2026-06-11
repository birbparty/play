import bddy
import music_fades

spec "music fade demo example":
  it "runs headlessly with streamed OGG fades":
    given:
      var config = defaultMusicFadeConfig()
      var result = MusicFadeResult()
    act:
      config.holdMs = 0
      result = runMusicFadeDemo(config)
    then:
      result.ok == true
      result.musicLoaded == true
      result.previewPlayed == true
      result.fadeInPlayed == true
      result.loopEnabled == true
      result.fadeOutScheduled == true
