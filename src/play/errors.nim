## Shared error and result conventions for play wrapper APIs.

type
  PlayErrorKind* = enum
    initFailed
    unsupportedBackend
    loadFailed
    invalidAsset
    invalidHandle
    allocationFailed

  PlayError* = object
    kind*: PlayErrorKind
    code*: cint
    message*: string

  PlayResult* = object
    ok*: bool
    error*: PlayError

  PlayException* = object of CatchableError
    error*: PlayError

proc playError*(kind: PlayErrorKind, message: string, code: cint = 0): PlayError =
  PlayError(kind: kind, code: code, message: message)

proc success*(): PlayResult =
  PlayResult(ok: true)

proc failure*(error: PlayError): PlayResult =
  PlayResult(ok: false, error: error)

proc raisePlayError*(error: PlayError) {.noReturn.} =
  var exception = newException(PlayException, error.message)
  exception.error = error
  raise exception

proc raiseIfFailed*(result: PlayResult) =
  if not result.ok:
    raisePlayError(result.error)

proc initError*(message: string, code: cint): PlayError =
  playError(initFailed, message, code)

proc unsupportedBackendError*(message: string, code: cint = 0): PlayError =
  playError(unsupportedBackend, message, code)

proc loadError*(message: string, code: cint = 0): PlayError =
  playError(loadFailed, message, code)

proc invalidAssetError*(message: string): PlayError =
  playError(invalidAsset, message)

proc invalidHandleError*(message: string): PlayError =
  playError(invalidHandle, message)

proc allocationError*(message: string): PlayError =
  playError(allocationFailed, message, -1)
