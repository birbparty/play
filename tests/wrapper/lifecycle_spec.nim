import bddy
import play/soloud

spec "SoLoud lifecycle wrapper":
  it "initializes and shuts down idempotently with NULLDRIVER":
    given:
      let engine = newEngine()
      let options = initOptions(
        backend = nullBackend,
        sampleRate = 44100'u32,
        bufferSize = 2048'u32,
        channels = 2'u32
      )
      var firstInit: PlayResult
      var secondInit: PlayResult
      var reinit: PlayResult
      var restored: PlayResult
      var backend: Backend
    act:
      firstInit = engine.init(options)
      secondInit = engine.init(options)
      backend = engine.activeBackend()
      engine.shutdown()
      reinit = engine.init(options)
      engine.shutdown()
      engine.destroy()
      restored = engine.init(options)
      engine.destroy()
      engine.destroy()
    then:
      firstInit.ok == true
      secondInit.ok == true
      reinit.ok == true
      restored.ok == true
      backend == nullBackend
      engine.isInitialized == false

  it "reports init errors without exposing raw handles":
    given:
      let engine = newEngine()
      let badOptions = initOptions(backend = Backend(9999'u32))
      var result: PlayResult
    act:
      result = engine.init(badOptions)
      engine.shutdown()
      engine.destroy()
    then:
      result.ok == false
      result.error.code != 0
      result.error.kind == unsupportedBackend
      result.error.message.len > 0
      engine.isInitialized == false
