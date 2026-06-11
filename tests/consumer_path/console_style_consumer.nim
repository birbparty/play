import play

let started = init(initOptions(backend = nullBackend))
started.raiseIfFailed()
shutdown()
