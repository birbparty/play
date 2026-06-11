import bddy
import play
import vita_audio_probe

spec "vita audio probe example":
  it "runs headlessly with the null backend":
    given:
      var config = defaultProbeConfig()
      var result = ProbeResult()
    act:
      result = runVitaAudioProbe(config)
    then:
      result.ok == true
      result.initOk == true
      result.logOpened == true
      result.sfxLoaded == true
      result.musicLoaded == true
      result.sfxPlayed == true
      result.musicPlayed == true
      result.failure == ""

  it "reports a failure state when init cannot succeed":
    given:
      var config = defaultProbeConfig()
      var result = ProbeResult()
    act:
      config.options = initOptions(backend = Backend(0xFFFF'u32))
      config.logPath = ""
      result = runVitaAudioProbe(config)
    then:
      result.ok == false
      result.initOk == false
      result.failure.len > 0
