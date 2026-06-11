import bddy
import play/soloud

spec "play error conventions":
  it "classifies explicit backend init failures as unsupported backend errors":
    given:
      let engine = newEngine()
      var result: PlayResult
      var reusable: PlayResult
    act:
      result = engine.init(initOptions(backend = Backend(9999'u32)))
      reusable = engine.init(initOptions(backend = nullBackend))
      engine.destroy()
    then:
      result.ok == false
      result.error.kind == unsupportedBackend
      result.error.code != 0
      result.error.message.len > 0
      reusable.ok == true

  it "classifies valid backend parameter failures as init failures":
    given:
      let engine = newEngine()
      var result: PlayResult
      var reusable: PlayResult
    act:
      result = engine.init(initOptions(backend = nullBackend, channels = 3'u32))
      reusable = engine.init(initOptions(backend = nullBackend))
      engine.destroy()
    then:
      result.ok == false
      result.error.kind == initFailed
      result.error.code != 0
      result.error.message.len > 0
      reusable.ok == true

  it "raises typed exceptions from failed results":
    given:
      let error = invalidHandleError("voice handle is no longer valid")
      var caught = false
      var kind = initFailed
      var message = ""
    act:
      try:
        failure(error).raiseIfFailed()
      except PlayException as exc:
        caught = true
        kind = exc.error.kind
        message = exc.msg
    then:
      caught == true
      kind == invalidHandle
      message == "voice handle is no longer valid"

  it "constructs common wrapper error categories consistently":
    given:
      let load = loadError("failed to load asset", 123)
      let asset = invalidAssetError("asset has been disposed")
      let handle = invalidHandleError("voice handle is stale")
    then:
      load.kind == loadFailed
      load.code == 123
      asset.kind == invalidAsset
      asset.code == 0
      handle.kind == invalidHandle
      handle.message.len > 0
