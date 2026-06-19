import bddy
import play

spec "audible backend detection":
  it "reports the NULL driver as not audible with a non-empty backend string":
    given:
      var started: PlayResult
      var audible = true
      var name = ""
    act:
      started = init(initOptions(backend = nullBackend))
      audible = isAudibleBackend()
      name = backendString()
      shutdown()
    then:
      started.ok == true
      audible == false
      name.len > 0

  it "reports the silent NoSound backend as not audible":
    given:
      var started: PlayResult
      var audible = true
    act:
      started = init(initOptions(backend = noSoundBackend))
      audible = isAudibleBackend()
      shutdown()
    then:
      started.ok == true
      audible == false

  it "reports not audible and an empty backend string before init":
    given:
      var audible = true
      var name = "x"
    act:
      audible = isAudibleBackend()
      name = backendString()
    then:
      audible == false
      name == ""

  it "reports not audible and an empty backend string after shutdown":
    given:
      var audible = true
      var name = "x"
    act:
      discard init(initOptions(backend = nullBackend))
      shutdown()
      audible = isAudibleBackend()
      name = backendString()
    then:
      audible == false
      name == ""
