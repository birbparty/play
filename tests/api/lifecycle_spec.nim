import bddy
import play

spec "public lifecycle API":
  it "initializes and shuts down from the top-level play import":
    given:
      let options = initOptions(backend = nullBackend)
      var started: PlayResult
      var repeated: PlayResult
      var backend: Backend
    act:
      started = init(options)
      repeated = init(options)
      backend = activeBackend()
      shutdown()
      shutdown()
    then:
      started.ok == true
      repeated.ok == true
      backend == nullBackend
      lifecycleState() == lifecycleStopped

  it "reports public init failures clearly and remains reusable":
    given:
      var failed: PlayResult
      var recovered: PlayResult
    act:
      failed = init(initOptions(backend = Backend(9999'u32)))
      recovered = init(initOptions(backend = nullBackend))
      shutdown()
    then:
      failed.ok == false
      failed.error.kind == unsupportedBackend
      failed.error.message.len > 0
      recovered.ok == true
      lifecycleState() == lifecycleStopped

  it "shuts down after withPlay even when the body raises":
    given:
      var caught = false
    act:
      try:
        withPlay(initOptions(backend = nullBackend), proc () =
          raise newException(ValueError, "boom")
        )
      except ValueError:
        caught = true
    then:
      caught == true
      lifecycleState() == lifecycleStopped

  it "withPlay preserves an already-running global lifecycle":
    given:
      var started: PlayResult
      var bodyRan = false
    act:
      started = init(initOptions(backend = nullBackend))
      withPlay(initOptions(backend = nullBackend), proc () =
        bodyRan = lifecycleState() == lifecycleRunning
      )
    then:
      started.ok == true
      bodyRan == true
      lifecycleState() == lifecycleRunning
    cleanup:
      shutdown()

  it "keeps raw backend mapping helpers out of top-level play":
    then:
      compiles(rawBackendId(defaultBackend)) == false
      compiles(rawInitFlags({clipRoundoff})) == false
      compiles(rawInitArgs(initOptions())) == false
      compiles(currentEngine()) == false
