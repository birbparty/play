## Internal helpers for public opaque value types.

import play/bindings/soloud_raw as raw

type
  Handle* = object
    id: uint32

const noHandle* = Handle(id: 0'u32)

proc handleFromRaw*(handle: raw.VoiceHandle): Handle =
  Handle(id: uint32(handle))

proc rawVoiceHandle*(handle: Handle): raw.VoiceHandle =
  raw.VoiceHandle(handle.id)

proc isValid*(handle: Handle): bool =
  handle.id != 0

proc `==`*(left, right: Handle): bool =
  left.id == right.id

proc `$`*(handle: Handle): string =
  "Handle(" & $handle.id & ")"
