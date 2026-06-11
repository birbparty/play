import play

let started = init(initOptions(backend = nullBackend))
started.raiseIfFailed()

doAssert lifecycleState() == lifecycleRunning
doAssert activeBackend() == nullBackend

shutdown()
doAssert lifecycleState() == lifecycleStopped
